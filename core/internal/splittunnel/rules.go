package splittunnel

import "strings"

// sanitizeDomain strips protocol, path, port from a domain string.
// Handles cases where user pastes a URL instead of a bare domain.
func sanitizeDomain(d string) string {
	d = strings.TrimSpace(d)
	// Strip protocol
	for _, prefix := range []string{"https://", "http://"} {
		d = strings.TrimPrefix(d, prefix)
	}
	// Strip path
	if idx := strings.IndexByte(d, '/'); idx != -1 {
		d = d[:idx]
	}
	// Strip port
	if idx := strings.IndexByte(d, ':'); idx != -1 {
		d = d[:idx]
	}
	return strings.TrimSpace(d)
}

// BuildAppRules generates sing-box route rules for per-app split tunneling.
// If invert is false ("only selected apps use VPN"): selected -> proxy
// If invert is true ("all except selected use VPN"): selected -> direct
func BuildAppRules(apps []string, invert bool) []interface{} {
	if len(apps) == 0 {
		return nil
	}

	outbound := "proxy"
	if invert {
		outbound = "direct"
	}

	return []interface{}{
		map[string]interface{}{
			"process_name": apps,
			"outbound":     outbound,
		},
	}
}

// BuildDomainRules generates sing-box route rules for per-domain split tunneling.
// If invert is false ("only selected domains use VPN"): selected -> proxy
// If invert is true ("all except selected use VPN"): selected -> direct
func BuildDomainRules(domains []string, invert bool) []interface{} {
	if len(domains) == 0 {
		return nil
	}

	outbound := "proxy"
	if invert {
		outbound = "direct"
	}

	// Separate full domains from suffixes
	var fullDomains []string
	var domainSuffixes []string

	for _, d := range domains {
		d = sanitizeDomain(d)
		if d == "" {
			continue
		}
		if d[0] == '.' {
			domainSuffixes = append(domainSuffixes, d[1:])
		} else {
			// Treat as both exact domain and suffix
			fullDomains = append(fullDomains, d)
			domainSuffixes = append(domainSuffixes, d)
		}
	}

	rule := map[string]interface{}{
		"outbound": outbound,
	}

	if len(fullDomains) > 0 {
		rule["domain"] = fullDomains
	}
	if len(domainSuffixes) > 0 {
		rule["domain_suffix"] = domainSuffixes
	}

	return []interface{}{rule}
}
