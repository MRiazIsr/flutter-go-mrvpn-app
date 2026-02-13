package ipc

import "encoding/json"

// Request represents a JSON-RPC request from the Flutter UI.
type Request struct {
	ID     string          `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params,omitempty"`
}

// Response represents a JSON-RPC response sent back to the Flutter UI.
type Response struct {
	ID     string      `json:"id"`
	Result interface{} `json:"result,omitempty"`
	Error  *RPCError   `json:"error,omitempty"`
}

// Notification represents a server-initiated push message (no ID).
type Notification struct {
	Method string      `json:"method"`
	Params interface{} `json:"params,omitempty"`
}

// RPCError represents an error in a JSON-RPC response.
type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// Standard error codes.
const (
	ErrCodeParseError     = -32700
	ErrCodeInvalidRequest = -32600
	ErrCodeMethodNotFound = -32601
	ErrCodeInvalidParams  = -32602
	ErrCodeInternal       = -32603
)

// VPN state constants.
const (
	StateDisconnected = "disconnected"
	StateConnecting   = "connecting"
	StateConnected    = "connected"
	StateDisconnecting = "disconnecting"
	StateError        = "error"
)

// ConnectParams are parameters for the vpn.connect method.
type ConnectParams struct {
	Link            string   `json:"link"`
	SplitTunnelMode string   `json:"splitTunnelMode,omitempty"` // "off", "app", "domain"
	SplitTunnelApps []string `json:"splitTunnelApps,omitempty"`
	SplitTunnelDomains []string `json:"splitTunnelDomains,omitempty"`
	SplitTunnelInvert  bool   `json:"splitTunnelInvert,omitempty"` // true = "all except selected"
}

// StatusResult is the result of vpn.status.
type StatusResult struct {
	State       string `json:"state"`
	ServerName  string `json:"serverName,omitempty"`
	Protocol    string `json:"protocol,omitempty"`
	ConnectedAt int64  `json:"connectedAt,omitempty"`
	Upload      int64  `json:"upload,omitempty"`
	Download    int64  `json:"download,omitempty"`
	UpSpeed     int64  `json:"upSpeed,omitempty"`
	DownSpeed   int64  `json:"downSpeed,omitempty"`
}

// StateChangedParams are params pushed via vpn.stateChanged notification.
type StateChangedParams struct {
	State      string `json:"state"`
	Error      string `json:"error,omitempty"`
	ServerName string `json:"serverName,omitempty"`
}

// StatsUpdateParams are params pushed via vpn.statsUpdate notification.
type StatsUpdateParams struct {
	Upload    int64 `json:"upload"`
	Download  int64 `json:"download"`
	UpSpeed   int64 `json:"upSpeed"`
	DownSpeed int64 `json:"downSpeed"`
}

// AppInfo describes an installed Windows application.
type AppInfo struct {
	Name        string `json:"name"`
	ExeName     string `json:"exeName"`
	InstallPath string `json:"installPath,omitempty"`
	IsUWP       bool   `json:"isUwp"`
}

// SplitTunnelConfig represents the current split tunnel configuration.
type SplitTunnelConfig struct {
	Mode    string   `json:"mode"`    // "off", "app", "domain"
	Apps    []string `json:"apps"`    // exe names
	Domains []string `json:"domains"` // domain suffixes
	Invert  bool     `json:"invert"`  // true = "all except selected"
}

// PingParams are parameters for the servers.ping method.
type PingParams struct {
	Link string `json:"link"`
}

// PingResult is the result of servers.ping.
type PingResult struct {
	Latency int    `json:"latency"` // milliseconds
	Error   string `json:"error,omitempty"`
}
