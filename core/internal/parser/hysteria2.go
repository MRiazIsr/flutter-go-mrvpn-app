package parser

import (
	"fmt"
	"log"
	"net/url"
	"strconv"
	"strings"
)

// ParseHysteria2 parses a Hysteria2 URI into a ServerConfig.
// Format: hysteria2://password@host:port?params#name
// Also supports: hy2://password@host:port?params#name
func ParseHysteria2(link string) (*ServerConfig, error) {
	if !strings.HasPrefix(link, "hysteria2://") && !strings.HasPrefix(link, "hy2://") {
		return nil, fmt.Errorf("not a Hysteria2 link")
	}

	// Normalize to hysteria2://
	normalized := link
	if strings.HasPrefix(link, "hy2://") {
		normalized = "hysteria2://" + link[6:]
	}

	// Replace hysteria2:// with https:// for URL parsing
	u, err := url.Parse("https://" + normalized[12:])
	if err != nil {
		return nil, fmt.Errorf("failed to parse Hysteria2 URI: %w", err)
	}

	password := u.User.Username()
	if password == "" {
		return nil, fmt.Errorf("Hysteria2 link missing password")
	}

	host := u.Hostname()
	if host == "" {
		return nil, fmt.Errorf("Hysteria2 link missing host")
	}

	portStr := u.Port()
	if portStr == "" {
		portStr = "443"
	}
	port, err := strconv.ParseUint(portStr, 10, 16)
	if err != nil {
		return nil, fmt.Errorf("invalid port: %s", portStr)
	}

	name := u.Fragment
	if name == "" {
		name = host
	}
	name, _ = url.QueryUnescape(name)

	params := make(map[string]string)
	params["password"] = password

	for key, values := range u.Query() {
		if len(values) > 0 {
			params[key] = values[0]
		}
	}

	return &ServerConfig{
		Protocol: "hysteria2",
		Name:     name,
		Address:  host,
		Port:     uint16(port),
		Params:   params,
	}, nil
}

// BuildHysteria2Outbound builds a sing-box outbound config map for Hysteria2.
func BuildHysteria2Outbound(cfg *ServerConfig) map[string]interface{} {
	outbound := map[string]interface{}{
		"type":        "hysteria2",
		"tag":         "proxy",
		"server":      cfg.Address,
		"server_port": cfg.Port,
		"password":    cfg.Params["password"],
	}

	// TLS (always enabled for Hysteria2)
	tlsCfg := map[string]interface{}{
		"enabled": true,
	}
	if sni, ok := cfg.Params["sni"]; ok && sni != "" {
		tlsCfg["server_name"] = sni
	}
	if alpn, ok := cfg.Params["alpn"]; ok && alpn != "" {
		tlsCfg["alpn"] = strings.Split(alpn, ",")
	}
	if insecure, ok := cfg.Params["insecure"]; ok && insecure == "1" {
		log.Printf("WARNING: TLS certificate verification DISABLED for %s:%d — connection is vulnerable to MITM", cfg.Address, cfg.Port)
		tlsCfg["insecure"] = true
	}
	outbound["tls"] = tlsCfg

	// Obfuscation
	if obfs, ok := cfg.Params["obfs"]; ok && obfs != "" {
		obfsCfg := map[string]interface{}{
			"type": obfs,
		}
		if obfsPassword, ok := cfg.Params["obfs-password"]; ok {
			obfsCfg["password"] = obfsPassword
		}
		outbound["obfs"] = obfsCfg
	}

	// Bandwidth hints
	if up, ok := cfg.Params["up"]; ok {
		outbound["up_mbps"] = parseIntOrDefault(up, 0)
	}
	if down, ok := cfg.Params["down"]; ok {
		outbound["down_mbps"] = parseIntOrDefault(down, 0)
	}

	return outbound
}

func parseIntOrDefault(s string, def int) int {
	v, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return v
}
