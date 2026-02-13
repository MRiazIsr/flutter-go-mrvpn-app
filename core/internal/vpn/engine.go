package vpn

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
)

// Engine manages the sing-box instance lifecycle.
type Engine struct {
	mu           sync.Mutex
	box          *box.Box
	cancel       context.CancelFunc
	stateMachine *StateMachine
	config       *Config
	connectedAt  time.Time
	lastUpload   int64
	lastDownload int64

	// Proxy-only traffic tracking.
	proxyConns    map[string]connTraffic // active proxy connection traffic
	closedUpload  int64                  // accumulated upload from closed proxy connections
	closedDownload int64                 // accumulated download from closed proxy connections
}

// NewEngine creates a new VPN engine.
func NewEngine(sm *StateMachine) *Engine {
	return &Engine{
		stateMachine: sm,
		config:       DefaultConfig(),
	}
}

// Connect starts the VPN connection with the given config.
func (e *Engine) Connect(cfg *Config) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.box != nil {
		return fmt.Errorf("already connected, disconnect first")
	}

	e.stateMachine.SetState(StateConnecting, nil)

	// Build sing-box JSON config
	configJSON, err := BuildSingBoxConfig(cfg)
	if err != nil {
		e.stateMachine.SetState(StateError, err)
		return fmt.Errorf("failed to build config: %w", err)
	}

	log.Printf("sing-box config: %s", string(configJSON))

	// Create context with sing-box type registries (required for 1.12+).
	ctx, cancel := context.WithCancel(include.Context(context.Background()))

	// Parse config into sing-box options
	var opts option.Options
	if err := opts.UnmarshalJSONContext(ctx, configJSON); err != nil {
		cancel()
		e.stateMachine.SetState(StateError, err)
		return fmt.Errorf("failed to parse sing-box options: %w", err)
	}

	// Create sing-box instance
	instance, err := box.New(box.Options{
		Context: ctx,
		Options: opts,
	})
	if err != nil {
		cancel()
		e.stateMachine.SetState(StateError, err)
		return fmt.Errorf("failed to create sing-box instance: %w", err)
	}

	// Start sing-box
	if err := instance.Start(); err != nil {
		cancel()
		instance.Close()
		e.stateMachine.SetState(StateError, err)
		return fmt.Errorf("failed to start sing-box: %w", err)
	}

	e.box = instance
	e.cancel = cancel
	e.config = cfg
	e.connectedAt = time.Now()
	e.lastUpload = 0
	e.lastDownload = 0
	e.proxyConns = make(map[string]connTraffic)
	e.closedUpload = 0
	e.closedDownload = 0

	e.stateMachine.SetState(StateConnected, nil)

	// Start stats polling
	go e.pollStats(ctx)

	return nil
}

// Disconnect stops the VPN connection.
func (e *Engine) Disconnect() error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.box == nil {
		return nil
	}

	e.stateMachine.SetState(StateDisconnecting, nil)

	if e.cancel != nil {
		e.cancel()
		e.cancel = nil
	}

	if err := e.box.Close(); err != nil {
		log.Printf("warning: error closing sing-box: %v", err)
	}
	e.box = nil

	e.stateMachine.SetState(StateDisconnected, nil)
	return nil
}

// ConnectedAt returns the time the VPN connected.
func (e *Engine) ConnectedAt() time.Time {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.connectedAt
}

// Config returns the current config.
func (e *Engine) Config() *Config {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.config
}

// clashConnections is the response structure from the Clash API /connections endpoint.
type clashConnections struct {
	DownloadTotal int64              `json:"downloadTotal"`
	UploadTotal   int64              `json:"uploadTotal"`
	Connections   []clashConnection  `json:"connections"`
}

// clashConnection represents a single active connection from the Clash API.
type clashConnection struct {
	ID       string   `json:"id"`
	Upload   int64    `json:"upload"`
	Download int64    `json:"download"`
	Chains   []string `json:"chains"`
}

// connTraffic tracks the last-seen traffic for a proxy connection.
type connTraffic struct {
	upload   int64
	download int64
}

// isProxyChain returns true if any chain entry indicates proxy outbound.
func isProxyChain(chains []string) bool {
	for _, c := range chains {
		if c == "proxy" {
			return true
		}
	}
	return false
}

func (e *Engine) pollStats(ctx context.Context) {
	// Give the Clash API a moment to start listening.
	select {
	case <-ctx.Done():
		return
	case <-time.After(1 * time.Second):
	}

	client := &http.Client{Timeout: 2 * time.Second}
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			e.mu.Lock()
			if e.box == nil {
				e.mu.Unlock()
				return
			}
			e.mu.Unlock()

			// Query the Clash API for per-connection traffic.
			resp, err := client.Get("http://127.0.0.1:9090/connections")
			if err != nil {
				continue
			}

			var conns clashConnections
			if err := json.NewDecoder(resp.Body).Decode(&conns); err != nil {
				resp.Body.Close()
				continue
			}
			resp.Body.Close()

			// Sum traffic only for connections routed through "proxy" outbound.
			activeIDs := make(map[string]struct{})
			var activeUpload, activeDownload int64
			for _, c := range conns.Connections {
				if !isProxyChain(c.Chains) {
					continue
				}
				activeIDs[c.ID] = struct{}{}
				activeUpload += c.Upload
				activeDownload += c.Download
			}

			e.mu.Lock()
			// Detect closed proxy connections and accumulate their last-seen traffic.
			for id, traffic := range e.proxyConns {
				if _, still := activeIDs[id]; !still {
					e.closedUpload += traffic.upload
					e.closedDownload += traffic.download
					delete(e.proxyConns, id)
				}
			}
			// Update tracker with current active proxy connections.
			for _, c := range conns.Connections {
				if !isProxyChain(c.Chains) {
					continue
				}
				e.proxyConns[c.ID] = connTraffic{upload: c.Upload, download: c.Download}
			}

			// Total proxy traffic = closed accumulator + active proxy traffic.
			upload := e.closedUpload + activeUpload
			download := e.closedDownload + activeDownload

			upSpeed := upload - e.lastUpload
			downSpeed := download - e.lastDownload
			if upSpeed < 0 {
				upSpeed = 0
			}
			if downSpeed < 0 {
				downSpeed = 0
			}
			e.lastUpload = upload
			e.lastDownload = download
			e.mu.Unlock()

			e.stateMachine.NotifyStats(upload, download, upSpeed, downSpeed)
		}
	}
}
