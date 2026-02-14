package ipc

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"sync"
	"time"

	"github.com/mriaz/vpn-core/internal/parser"
	"github.com/mriaz/vpn-core/internal/splittunnel"
	"github.com/mriaz/vpn-core/internal/vpn"
)

// Handler dispatches RPC method calls.
type Handler struct {
	engine       *vpn.Engine
	stateMachine *vpn.StateMachine
	mu           sync.RWMutex
	splitConfig  *SplitTunnelConfig
	ShutdownCh   chan struct{}
}

// NewHandler creates a new RPC handler.
func NewHandler(engine *vpn.Engine, sm *vpn.StateMachine) *Handler {
	return &Handler{
		engine:       engine,
		stateMachine: sm,
		splitConfig: &SplitTunnelConfig{
			Mode: "off",
		},
		ShutdownCh: make(chan struct{}),
	}
}

// Handle processes a single RPC request and returns a response.
func (h *Handler) Handle(req *Request) *Response {
	switch req.Method {
	case "vpn.connect":
		return h.handleConnect(req)
	case "vpn.disconnect":
		return h.handleDisconnect(req)
	case "vpn.status":
		return h.handleStatus(req)
	case "apps.list":
		return h.handleAppsList(req)
	case "split.setConfig":
		return h.handleSplitSetConfig(req)
	case "split.getConfig":
		return h.handleSplitGetConfig(req)
	case "servers.ping":
		return h.handlePing(req)
	case "service.shutdown":
		return h.handleShutdown(req)
	default:
		return &Response{
			ID: req.ID,
			Error: &RPCError{
				Code:    ErrCodeMethodNotFound,
				Message: fmt.Sprintf("method not found: %s", req.Method),
			},
		}
	}
}

func (h *Handler) handleConnect(req *Request) *Response {
	var params ConnectParams
	if err := json.Unmarshal(req.Params, &params); err != nil {
		return errorResponse(req.ID, ErrCodeInvalidParams, "invalid parameters")
	}

	// Validate link length
	if len(params.Link) > 2048 {
		return errorResponse(req.ID, ErrCodeInvalidParams, "server link is too long")
	}

	// Parse the server link
	serverCfg, err := parser.ParseLink(params.Link)
	if err != nil {
		log.Printf("vpn.connect: failed to parse link: %v", err)
		return errorResponse(req.ID, ErrCodeInvalidParams, "failed to parse server link")
	}

	// Build VPN config
	cfg := vpn.DefaultConfig()
	cfg.Server = serverCfg
	cfg.SplitTunnelMode = params.SplitTunnelMode
	cfg.SplitTunnelApps = params.SplitTunnelApps
	cfg.SplitTunnelDomains = params.SplitTunnelDomains
	cfg.SplitTunnelInvert = params.SplitTunnelInvert

	// Use stored split tunnel config if not provided in connect params
	if cfg.SplitTunnelMode == "" {
		h.mu.RLock()
		cfg.SplitTunnelMode = h.splitConfig.Mode
		cfg.SplitTunnelApps = h.splitConfig.Apps
		cfg.SplitTunnelDomains = h.splitConfig.Domains
		cfg.SplitTunnelInvert = h.splitConfig.Invert
		h.mu.RUnlock()
	}

	if err := h.engine.Connect(cfg); err != nil {
		log.Printf("vpn.connect: connection failed: %v", err)
		return errorResponse(req.ID, ErrCodeInternal, "connection failed")
	}

	return &Response{
		ID:     req.ID,
		Result: map[string]interface{}{"ok": true},
	}
}

func (h *Handler) handleDisconnect(req *Request) *Response {
	if err := h.engine.Disconnect(); err != nil {
		log.Printf("vpn.disconnect failed: %v", err)
		return errorResponse(req.ID, ErrCodeInternal, "disconnect failed")
	}
	return &Response{
		ID:     req.ID,
		Result: map[string]interface{}{"ok": true},
	}
}

func (h *Handler) handleStatus(req *Request) *Response {
	state := h.stateMachine.State()
	result := StatusResult{
		State: string(state),
	}

	if state == vpn.StateConnected {
		result.ConnectedAt = h.engine.ConnectedAt().Unix()
		cfg := h.engine.Config()
		if cfg != nil && cfg.Server != nil {
			result.ServerName = cfg.Server.Name
			result.Protocol = cfg.Server.Protocol
		}
	}

	if state == vpn.StateError {
		if err := h.stateMachine.LastError(); err != nil {
			result.State = string(vpn.StateError)
		}
	}

	return &Response{
		ID:     req.ID,
		Result: result,
	}
}

func (h *Handler) handleAppsList(req *Request) *Response {
	apps, err := splittunnel.ListInstalledApps()
	if err != nil {
		log.Printf("apps.list failed: %v", err)
		return errorResponse(req.ID, ErrCodeInternal, "failed to list apps")
	}
	return &Response{
		ID:     req.ID,
		Result: apps,
	}
}

func (h *Handler) handleSplitSetConfig(req *Request) *Response {
	var config SplitTunnelConfig
	if err := json.Unmarshal(req.Params, &config); err != nil {
		return errorResponse(req.ID, ErrCodeInvalidParams, "invalid parameters")
	}

	// Validate mode
	switch config.Mode {
	case "off", "app", "domain":
		// valid
	default:
		return errorResponse(req.ID, ErrCodeInvalidParams, "invalid mode: must be off, app, or domain")
	}

	h.mu.Lock()
	h.splitConfig = &config
	h.mu.Unlock()
	return &Response{
		ID:     req.ID,
		Result: map[string]interface{}{"ok": true},
	}
}

func (h *Handler) handleSplitGetConfig(req *Request) *Response {
	h.mu.RLock()
	cfg := h.splitConfig
	h.mu.RUnlock()
	return &Response{
		ID:     req.ID,
		Result: cfg,
	}
}

// isPrivateAddress checks if a host resolves to a private/loopback/link-local IP.
func isPrivateAddress(host string) bool {
	ip := net.ParseIP(host)
	if ip == nil {
		// Hostname — resolve it first
		addrs, err := net.LookupIP(host)
		if err != nil || len(addrs) == 0 {
			return true // block if unresolvable
		}
		ip = addrs[0]
	}
	return ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsUnspecified()
}

func (h *Handler) handlePing(req *Request) *Response {
	var params PingParams
	if err := json.Unmarshal(req.Params, &params); err != nil {
		return errorResponse(req.ID, ErrCodeInvalidParams, "invalid parameters")
	}

	serverCfg, err := parser.ParseLink(params.Link)
	if err != nil {
		return &Response{
			ID:     req.ID,
			Result: PingResult{Error: "failed to parse link"},
		}
	}

	// SSRF protection: block private/loopback addresses
	if isPrivateAddress(serverCfg.Address) {
		return &Response{
			ID:     req.ID,
			Result: PingResult{Error: "cannot ping private addresses"},
		}
	}

	// Simple TCP connect to measure latency
	start := time.Now()
	addr := fmt.Sprintf("%s:%d", serverCfg.Address, serverCfg.Port)
	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		return &Response{
			ID:     req.ID,
			Result: PingResult{Error: "connection failed"},
		}
	}
	conn.Close()
	latency := time.Since(start).Milliseconds()

	return &Response{
		ID:     req.ID,
		Result: PingResult{Latency: int(latency)},
	}
}

func (h *Handler) handleShutdown(req *Request) *Response {
	log.Printf("Shutdown requested via IPC")
	// Signal main goroutine for graceful shutdown (runs deferred cleanup)
	go func() {
		time.Sleep(100 * time.Millisecond)
		close(h.ShutdownCh)
	}()
	return &Response{
		ID:     req.ID,
		Result: map[string]interface{}{"ok": true},
	}
}

func errorResponse(id string, code int, message string) *Response {
	log.Printf("RPC error [%s]: %s", id, message)
	return &Response{
		ID: id,
		Error: &RPCError{
			Code:    code,
			Message: message,
		},
	}
}
