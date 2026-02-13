package parser

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"
)

// ParseVLESS parses a VLESS URI into a ServerConfig.
// Format: vless://uuid@host:port?params#name
func ParseVLESS(link string) (*ServerConfig, error) {
	if !strings.HasPrefix(link, "vless://") {
		return nil, fmt.Errorf("not a VLESS link")
	}

	// Replace vless:// with https:// for URL parsing
	u, err := url.Parse("https://" + link[8:])
	if err != nil {
		return nil, fmt.Errorf("failed to parse VLESS URI: %w", err)
	}

	uuid := u.User.Username()
	if uuid == "" {
		return nil, fmt.Errorf("VLESS link missing UUID")
	}

	host := u.Hostname()
	if host == "" {
		return nil, fmt.Errorf("VLESS link missing host")
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
	params["uuid"] = uuid

	// Extract all query parameters
	for key, values := range u.Query() {
		if len(values) > 0 {
			params[key] = values[0]
		}
	}

	// Set defaults for common params
	if _, ok := params["type"]; !ok {
		params["type"] = "tcp"
	}
	if _, ok := params["security"]; !ok {
		params["security"] = "none"
	}

	return &ServerConfig{
		Protocol: "vless",
		Name:     name,
		Address:  host,
		Port:     uint16(port),
		Params:   params,
	}, nil
}

// BuildVLESSOutbound builds a sing-box outbound config map for VLESS.
func BuildVLESSOutbound(cfg *ServerConfig) map[string]interface{} {
	outbound := map[string]interface{}{
		"type":        "vless",
		"tag":         "proxy",
		"server":      cfg.Address,
		"server_port": cfg.Port,
		"uuid":        cfg.Params["uuid"],
	}

	// Flow (for XTLS)
	if flow, ok := cfg.Params["flow"]; ok && flow != "" {
		outbound["flow"] = flow
	}

	// Transport
	transport := cfg.Params["type"]
	switch transport {
	case "ws":
		wsTransport := map[string]interface{}{
			"type": "ws",
		}
		if path, ok := cfg.Params["path"]; ok {
			wsTransport["path"] = path
		}
		if host, ok := cfg.Params["host"]; ok {
			wsTransport["headers"] = map[string]interface{}{
				"Host": host,
			}
		}
		outbound["transport"] = wsTransport

	case "grpc":
		grpcTransport := map[string]interface{}{
			"type": "grpc",
		}
		if sn, ok := cfg.Params["serviceName"]; ok {
			grpcTransport["service_name"] = sn
		}
		outbound["transport"] = grpcTransport

	case "h2", "http":
		h2Transport := map[string]interface{}{
			"type": "http",
		}
		if path, ok := cfg.Params["path"]; ok {
			h2Transport["path"] = path
		}
		if host, ok := cfg.Params["host"]; ok {
			h2Transport["host"] = []string{host}
		}
		outbound["transport"] = h2Transport

	case "httpupgrade":
		httpUpgrade := map[string]interface{}{
			"type": "httpupgrade",
		}
		if path, ok := cfg.Params["path"]; ok {
			httpUpgrade["path"] = path
		}
		if host, ok := cfg.Params["host"]; ok {
			httpUpgrade["host"] = host
		}
		outbound["transport"] = httpUpgrade
	}

	// TLS
	security := cfg.Params["security"]
	switch security {
	case "tls":
		tlsCfg := map[string]interface{}{
			"enabled": true,
		}
		if sni, ok := cfg.Params["sni"]; ok {
			tlsCfg["server_name"] = sni
		}
		if alpn, ok := cfg.Params["alpn"]; ok && alpn != "" {
			tlsCfg["alpn"] = strings.Split(alpn, ",")
		}
		if fp, ok := cfg.Params["fp"]; ok && fp != "" {
			tlsCfg["utls"] = map[string]interface{}{
				"enabled":     true,
				"fingerprint": fp,
			}
		}
		outbound["tls"] = tlsCfg

	case "reality":
		realityCfg := map[string]interface{}{
			"enabled": true,
		}
		if sni, ok := cfg.Params["sni"]; ok {
			realityCfg["server_name"] = sni
		}
		reality := map[string]interface{}{
			"enabled": true,
		}
		if pbk, ok := cfg.Params["pbk"]; ok {
			reality["public_key"] = pbk
		}
		if sid, ok := cfg.Params["sid"]; ok {
			reality["short_id"] = sid
		}
		realityCfg["reality"] = reality
		if fp, ok := cfg.Params["fp"]; ok && fp != "" {
			realityCfg["utls"] = map[string]interface{}{
				"enabled":     true,
				"fingerprint": fp,
			}
		}
		outbound["tls"] = realityCfg
	}

	return outbound
}
