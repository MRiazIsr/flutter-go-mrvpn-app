package vpn

import (
	"encoding/json"
	"fmt"

	"github.com/mriaz/vpn-core/internal/parser"
	"github.com/mriaz/vpn-core/internal/splittunnel"
)

// Config holds the VPN configuration options.
type Config struct {
	Server          *parser.ServerConfig
	DNS             string   // "system", "cloudflare", "google", "custom"
	CustomDNS       string   // used when DNS == "custom"
	MTU             int
	KillSwitch      bool
	SplitTunnelMode string   // "off", "app", "domain"
	SplitTunnelApps []string // process names like "chrome.exe"
	SplitTunnelDomains []string
	SplitTunnelInvert  bool // true = "all except selected"
}

// DefaultConfig returns a Config with sensible defaults.
func DefaultConfig() *Config {
	return &Config{
		DNS:             "cloudflare",
		MTU:             9000,
		SplitTunnelMode: "off",
	}
}

// BuildSingBoxConfig builds a complete sing-box JSON configuration.
func BuildSingBoxConfig(cfg *Config) ([]byte, error) {
	if cfg.Server == nil {
		return nil, fmt.Errorf("no server configuration provided")
	}

	// Build outbound based on protocol
	var proxyOutbound map[string]interface{}
	switch cfg.Server.Protocol {
	case "vless":
		proxyOutbound = parser.BuildVLESSOutbound(cfg.Server)
	case "hysteria2":
		proxyOutbound = parser.BuildHysteria2Outbound(cfg.Server)
	default:
		return nil, fmt.Errorf("unsupported protocol: %s", cfg.Server.Protocol)
	}

	// DNS servers
	dnsServers := buildDNSConfig(cfg)

	// Route rules
	routeRules, finalOutbound := buildRouteRules(cfg)

	// Build the full config
	config := map[string]interface{}{
		"log": map[string]interface{}{
			"level":     "info",
			"timestamp": true,
		},
		"dns": dnsServers,
		"inbounds": []interface{}{
			map[string]interface{}{
				"type": "tun",
				"tag":  "tun-in",
				"interface_name":    "MRVPN",
				"inet4_address":     "172.19.0.1/30",
				"inet6_address":     "fdfe:dcba:9876::1/126",
				"mtu":               cfg.MTU,
				"auto_route":        true,
				"strict_route":      cfg.KillSwitch,
				"stack":             "mixed",
				"sniff":             true,
				"sniff_override_destination": true,
			},
		},
		"outbounds": []interface{}{
			proxyOutbound,
			map[string]interface{}{
				"type": "direct",
				"tag":  "direct",
			},
			map[string]interface{}{
				"type": "block",
				"tag":  "block",
			},
			map[string]interface{}{
				"type": "dns",
				"tag":  "dns-out",
			},
		},
		"route": map[string]interface{}{
			"rules":        routeRules,
			"final":        finalOutbound,
			"auto_detect_interface": true,
			"find_process": cfg.SplitTunnelMode == "app",
		},
		"experimental": map[string]interface{}{
			"clash_api": map[string]interface{}{
				"external_controller": "127.0.0.1:9090",
			},
		},
	}

	return json.MarshalIndent(config, "", "  ")
}

func buildDNSConfig(cfg *Config) map[string]interface{} {
	var remoteDNS, localDNS string

	switch cfg.DNS {
	case "google":
		remoteDNS = "https://dns.google/dns-query"
		localDNS = "8.8.8.8"
	case "custom":
		remoteDNS = cfg.CustomDNS
		localDNS = cfg.CustomDNS
	default: // cloudflare
		remoteDNS = "https://cloudflare-dns.com/dns-query"
		localDNS = "1.1.1.1"
	}

	return map[string]interface{}{
		"servers": []interface{}{
			map[string]interface{}{
				"tag":     "remote-dns",
				"address": remoteDNS,
				"detour":  "proxy",
			},
			map[string]interface{}{
				"tag":     "local-dns",
				"address": localDNS,
				"detour":  "direct",
			},
		},
		"rules": []interface{}{
			map[string]interface{}{
				"outbound": []string{"any"},
				"server":   "local-dns",
			},
		},
		"final": "remote-dns",
	}
}

func buildRouteRules(cfg *Config) ([]interface{}, string) {
	rules := []interface{}{
		// DNS hijack rule
		map[string]interface{}{
			"protocol": "dns",
			"outbound": "dns-out",
		},
	}

	finalOutbound := "proxy" // default: route everything through VPN

	switch cfg.SplitTunnelMode {
	case "app":
		appRules := splittunnel.BuildAppRules(cfg.SplitTunnelApps, cfg.SplitTunnelInvert)
		rules = append(rules, appRules...)
		if cfg.SplitTunnelInvert {
			// "all except selected" → selected apps go direct, rest go proxy
			finalOutbound = "proxy"
		} else {
			// "only selected" → selected apps go proxy, rest go direct
			finalOutbound = "direct"
		}

	case "domain":
		domainRules := splittunnel.BuildDomainRules(cfg.SplitTunnelDomains, cfg.SplitTunnelInvert)
		rules = append(rules, domainRules...)
		if cfg.SplitTunnelInvert {
			finalOutbound = "proxy"
		} else {
			finalOutbound = "direct"
		}
	}

	return rules, finalOutbound
}
