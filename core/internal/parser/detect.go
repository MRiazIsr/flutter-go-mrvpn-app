package parser

import (
	"fmt"
	"strings"
)

// ServerConfig holds parsed proxy server configuration.
type ServerConfig struct {
	Protocol string            `json:"protocol"` // "vless" or "hysteria2"
	Name     string            `json:"name"`
	Address  string            `json:"address"`
	Port     uint16            `json:"port"`
	Params   map[string]string `json:"params"` // protocol-specific parameters
}

// ParseLink auto-detects and parses a proxy link.
func ParseLink(link string) (*ServerConfig, error) {
	link = strings.TrimSpace(link)

	switch {
	case strings.HasPrefix(link, "vless://"):
		return ParseVLESS(link)
	case strings.HasPrefix(link, "hysteria2://"), strings.HasPrefix(link, "hy2://"):
		return ParseHysteria2(link)
	default:
		return nil, fmt.Errorf("unsupported link scheme: %s", link[:min(20, len(link))])
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
