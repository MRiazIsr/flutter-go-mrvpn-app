package splittunnel

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"golang.org/x/sys/windows/registry"
)

// AppInfo represents an installed Windows application.
type AppInfo struct {
	Name        string `json:"name"`
	ExeName     string `json:"exeName"`
	InstallPath string `json:"installPath,omitempty"`
	IsUWP       bool   `json:"isUwp"`
	Icon        string `json:"icon,omitempty"`
}

// ListInstalledApps returns all installed Windows applications.
func ListInstalledApps() ([]AppInfo, error) {
	var apps []AppInfo

	// Get Win32 apps from registry
	win32Apps, err := listWin32Apps()
	if err != nil {
		log.Printf("warning: failed to list Win32 apps: %v", err)
	} else {
		apps = append(apps, win32Apps...)
	}

	// Get UWP apps via PowerShell
	uwpApps, err := listUWPApps()
	if err != nil {
		log.Printf("warning: failed to list UWP apps: %v", err)
	} else {
		apps = append(apps, uwpApps...)
	}

	// Deduplicate by ExeName
	seen := make(map[string]bool)
	var unique []AppInfo
	for _, app := range apps {
		key := strings.ToLower(app.ExeName)
		if key == "" || seen[key] {
			continue
		}
		seen[key] = true
		unique = append(unique, app)
	}

	// Extract icons
	for i := range unique {
		exePath := resolveExePath(unique[i])
		unique[i].Icon = extractIconBase64(exePath)
	}

	// Sort alphabetically by name
	sort.Slice(unique, func(i, j int) bool {
		return strings.ToLower(unique[i].Name) < strings.ToLower(unique[j].Name)
	})

	return unique, nil
}

func listWin32Apps() ([]AppInfo, error) {
	var apps []AppInfo

	// Registry hives: system-wide (HKLM) and per-user (HKCU)
	type hive struct {
		root registry.Key
		name string
	}
	hives := []hive{
		{registry.LOCAL_MACHINE, "HKLM"},
		{registry.CURRENT_USER, "HKCU"},
	}

	// Check both 64-bit and 32-bit registry paths under each hive
	subPaths := []string{
		`SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`,
		`SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`,
	}

	for _, h := range hives {
		for _, regPath := range subPaths {
			key, err := registry.OpenKey(h.root, regPath, registry.READ)
			if err != nil {
				continue
			}

			subKeys, err := key.ReadSubKeyNames(-1)
			key.Close()
			if err != nil {
				continue
			}

			for _, subKeyName := range subKeys {
				subKey, err := registry.OpenKey(h.root, regPath+`\`+subKeyName, registry.READ)
				if err != nil {
					continue
				}

				displayName, _, _ := subKey.GetStringValue("DisplayName")
				installLocation, _, _ := subKey.GetStringValue("InstallLocation")
				displayIcon, _, _ := subKey.GetStringValue("DisplayIcon")
				uninstallString, _, _ := subKey.GetStringValue("UninstallString")
				subKey.Close()

				if displayName == "" {
					continue
				}

				exeName, exeDir := resolveAppExe(displayName, installLocation, displayIcon, uninstallString)
				if exeName == "" {
					continue
				}
				if exeDir != "" {
					installLocation = exeDir
				}

				apps = append(apps, AppInfo{
					Name:        displayName,
					ExeName:     exeName,
					InstallPath: installLocation,
					IsUWP:       false,
				})
			}
		}
	}

	return apps, nil
}

// resolveAppExe determines the exe name and its directory from registry values.
// Handles normal installs, DisplayIcon paths, and Squirrel/Electron apps
// (Discord, Telegram, Slack, VS Code, etc.) where the real exe lives in an
// app-<version> subdirectory.
func resolveAppExe(displayName, installLocation, displayIcon, uninstallString string) (exeName string, exeDir string) {
	// Strategy 1: DisplayIcon points directly to an exe.
	if displayIcon != "" {
		icon := strings.Split(displayIcon, ",")[0]
		icon = strings.Trim(icon, `"`)
		if strings.HasSuffix(strings.ToLower(icon), ".exe") {
			base := filepath.Base(icon)
			// Skip generic updaters — we want the real app exe.
			if !isUpdaterExe(base) {
				if _, err := os.Stat(icon); err == nil {
					return base, filepath.Dir(icon)
				}
			}
		}
	}

	// Strategy 2: Squirrel/Electron pattern — look in app-* subdirectories.
	// These apps (Discord, Telegram Desktop, Slack, etc.) have:
	//   InstallLocation/app-<version>/<AppName>.exe
	//   UninstallString contains Update.exe --uninstall
	if installLocation != "" {
		if exe := findExeInSquirrelApp(installLocation, displayName); exe != "" {
			return filepath.Base(exe), filepath.Dir(exe)
		}
	}

	// Strategy 3: Direct exe in InstallLocation (skip updaters).
	if installLocation != "" {
		if exe := findMainExeInDir(installLocation); exe != "" {
			return exe, installLocation
		}
	}

	// Strategy 4: Derive from UninstallString path.
	if uninstallString != "" {
		uPath := strings.Split(uninstallString, " ")[0]
		uPath = strings.Trim(uPath, `"`)
		if strings.HasSuffix(strings.ToLower(uPath), ".exe") && !isUpdaterExe(filepath.Base(uPath)) {
			if _, err := os.Stat(uPath); err == nil {
				return filepath.Base(uPath), filepath.Dir(uPath)
			}
		}
	}

	return "", ""
}

// findExeInSquirrelApp looks for app-<version> subdirectories (Squirrel pattern)
// and returns the path to the main exe inside the latest one.
func findExeInSquirrelApp(dir, displayName string) string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}

	// Find the latest app-* directory (sorted descending by name → latest version).
	var latestAppDir string
	for i := len(entries) - 1; i >= 0; i-- {
		e := entries[i]
		if e.IsDir() && strings.HasPrefix(e.Name(), "app-") {
			latestAppDir = filepath.Join(dir, e.Name())
			break
		}
	}
	if latestAppDir == "" {
		return ""
	}

	// Look for an exe in that directory, preferring one matching the display name.
	subEntries, err := os.ReadDir(latestAppDir)
	if err != nil {
		return ""
	}

	nameLower := strings.ToLower(strings.ReplaceAll(displayName, " ", ""))
	var fallback string
	for _, e := range subEntries {
		if e.IsDir() {
			continue
		}
		n := e.Name()
		nLower := strings.ToLower(n)
		if !strings.HasSuffix(nLower, ".exe") || isUpdaterExe(n) {
			continue
		}
		// Prefer exe whose name matches the display name.
		stripped := strings.ToLower(strings.TrimSuffix(n, filepath.Ext(n)))
		stripped = strings.ReplaceAll(stripped, " ", "")
		if stripped == nameLower || strings.Contains(nameLower, stripped) {
			return filepath.Join(latestAppDir, n)
		}
		if fallback == "" {
			fallback = filepath.Join(latestAppDir, n)
		}
	}

	return fallback
}

// findMainExeInDir finds the main exe in a directory, skipping known updaters.
func findMainExeInDir(dir string) string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasSuffix(strings.ToLower(name), ".exe") && !isUpdaterExe(name) {
			return name
		}
	}

	return ""
}

// isUpdaterExe returns true for known updater/helper executables that should
// be skipped in favor of the real application exe.
func isUpdaterExe(name string) bool {
	lower := strings.ToLower(name)
	return lower == "update.exe" ||
		lower == "unins000.exe" ||
		lower == "uninstall.exe" ||
		strings.Contains(lower, "updater") ||
		strings.Contains(lower, "uninstall") ||
		strings.Contains(lower, "helper")
}

func listUWPApps() ([]AppInfo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "powershell", "-NoProfile", "-Command",
		`Get-AppxPackage | Where-Object {$_.IsFramework -eq $false -and $_.SignatureKind -eq 'Store'} | ForEach-Object { $manifest = Get-AppxPackageManifest $_; $app = $manifest.Package.Applications.Application; if ($app) { $name = $_.Name; $exe = if ($app.Executable) { $app.Executable } else { 'N/A' }; "$name|$exe" } }`)

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("powershell Get-AppxPackage failed: %w", err)
	}

	var apps []AppInfo
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "|", 2)
		if len(parts) != 2 {
			continue
		}
		name := parts[0]
		exeName := filepath.Base(parts[1])
		if exeName == "" || exeName == "N/A" {
			continue
		}

		apps = append(apps, AppInfo{
			Name:    name,
			ExeName: exeName,
			IsUWP:   true,
		})
	}

	return apps, nil
}
