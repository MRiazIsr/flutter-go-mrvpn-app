package splittunnel

import (
	"encoding/json"
	"fmt"
	"testing"
)

func TestListInstalledApps(t *testing.T) {
	apps, err := ListInstalledApps()
	if err != nil {
		t.Fatalf("ListInstalledApps failed: %v", err)
	}

	fmt.Printf("Found %d apps\n", len(apps))

	withIcon := 0
	withoutIcon := 0
	for _, app := range apps {
		iconLen := len(app.Icon)
		if iconLen > 0 {
			withIcon++
		} else {
			withoutIcon++
		}
		fmt.Printf("  %-35s  exe=%-25s  icon=%d bytes  path=%s\n",
			app.Name, app.ExeName, iconLen, app.InstallPath)
	}

	fmt.Printf("\nIcon stats: %d with icon, %d without icon\n", withIcon, withoutIcon)

	// Check Discord specifically
	found := false
	for _, app := range apps {
		if app.ExeName == "Discord.exe" {
			found = true
			t.Logf("Discord found: %+v (icon bytes: %d)", app.Name, len(app.Icon))
		}
	}
	if !found {
		t.Error("Discord.exe not found in app list")
	}

	// Check total JSON size (simulating what handler sends)
	jsonData, err := json.Marshal(apps)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}
	fmt.Printf("\nTotal JSON response size: %d bytes (%.1f KB)\n", len(jsonData), float64(len(jsonData))/1024)

	// Output a sample with icon as JSON to verify structure
	for _, app := range apps {
		if len(app.Icon) > 0 {
			sample := app
			sample.Icon = sample.Icon[:min(20, len(sample.Icon))] + "..."
			b, _ := json.MarshalIndent(sample, "", "  ")
			fmt.Printf("\nSample app WITH icon:\n%s\n", string(b))
			break
		}
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
