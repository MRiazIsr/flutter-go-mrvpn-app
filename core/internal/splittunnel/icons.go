package splittunnel

import (
	"bytes"
	"encoding/base64"
	"errors"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	modShell32         = syscall.NewLazyDLL("shell32.dll")
	modUser32          = syscall.NewLazyDLL("user32.dll")
	modGdi32           = syscall.NewLazyDLL("gdi32.dll")
	procExtractIconExW = modShell32.NewProc("ExtractIconExW")
	procDestroyIcon    = modUser32.NewProc("DestroyIcon")
	procGetIconInfo    = modUser32.NewProc("GetIconInfo")
	procGetDC          = modUser32.NewProc("GetDC")
	procReleaseDC      = modUser32.NewProc("ReleaseDC")
	procCreateCompatDC = modGdi32.NewProc("CreateCompatibleDC")
	procDeleteDC       = modGdi32.NewProc("DeleteDC")
	procGetObjectW     = modGdi32.NewProc("GetObjectW")
	procGetDIBits      = modGdi32.NewProc("GetDIBits")
	procDeleteObject   = modGdi32.NewProc("DeleteObject")
)

// Windows struct layouts matching 64-bit ABI.

type winICONINFO struct {
	FIcon    int32
	XHotspot uint32
	YHotspot uint32
	HbmMask  uintptr
	HbmColor uintptr
}

type winBITMAP struct {
	Type       int32
	Width      int32
	Height     int32
	WidthBytes int32
	Planes     uint16
	BitsPixel  uint16
	Bits       uintptr
}

type winBITMAPINFOHEADER struct {
	Size          uint32
	Width         int32
	Height        int32
	Planes        uint16
	BitCount      uint16
	Compression   uint32
	SizeImage     uint32
	XPelsPerMeter int32
	YPelsPerMeter int32
	ClrUsed       uint32
	ClrImportant  uint32
}

// extractIconBase64 extracts the first icon from an exe file and returns it
// as a base64-encoded PNG string. Returns "" on any failure.
func extractIconBase64(exePath string) string {
	if exePath == "" {
		return ""
	}
	if _, err := os.Stat(exePath); err != nil {
		return ""
	}

	pathPtr, err := syscall.UTF16PtrFromString(exePath)
	if err != nil {
		return ""
	}

	var hLarge, hSmall uintptr
	ret, _, _ := procExtractIconExW.Call(
		uintptr(unsafe.Pointer(pathPtr)),
		0,
		uintptr(unsafe.Pointer(&hLarge)),
		uintptr(unsafe.Pointer(&hSmall)),
		1,
	)
	defer func() {
		if hLarge != 0 {
			procDestroyIcon.Call(hLarge)
		}
		if hSmall != 0 {
			procDestroyIcon.Call(hSmall)
		}
	}()

	if ret == 0 {
		return ""
	}

	hIcon := hLarge
	if hIcon == 0 {
		hIcon = hSmall
	}
	if hIcon == 0 {
		return ""
	}

	pngData, err := hIconToPNG(hIcon)
	if err != nil {
		return ""
	}

	return base64.StdEncoding.EncodeToString(pngData)
}

func hIconToPNG(hIcon uintptr) ([]byte, error) {
	var ii winICONINFO
	ret, _, _ := procGetIconInfo.Call(hIcon, uintptr(unsafe.Pointer(&ii)))
	if ret == 0 {
		return nil, errors.New("GetIconInfo failed")
	}
	defer func() {
		if ii.HbmMask != 0 {
			procDeleteObject.Call(ii.HbmMask)
		}
		if ii.HbmColor != 0 {
			procDeleteObject.Call(ii.HbmColor)
		}
	}()

	if ii.HbmColor == 0 {
		return nil, errors.New("no color bitmap")
	}

	var bm winBITMAP
	procGetObjectW.Call(ii.HbmColor, uintptr(unsafe.Sizeof(bm)), uintptr(unsafe.Pointer(&bm)))

	w := int(bm.Width)
	h := int(bm.Height)
	if w <= 0 || h <= 0 || w > 256 || h > 256 {
		return nil, errors.New("invalid bitmap size")
	}

	hdc, _, _ := procGetDC.Call(0)
	if hdc == 0 {
		return nil, errors.New("GetDC failed")
	}
	defer procReleaseDC.Call(0, hdc)

	memDC, _, _ := procCreateCompatDC.Call(hdc)
	if memDC == 0 {
		return nil, errors.New("CreateCompatibleDC failed")
	}
	defer procDeleteDC.Call(memDC)

	bih := winBITMAPINFOHEADER{
		Size:     40,
		Width:    int32(w),
		Height:   -int32(h), // top-down
		Planes:   1,
		BitCount: 32,
	}

	pixelCount := w * h * 4
	pixels := make([]byte, pixelCount)
	ret, _, _ = procGetDIBits.Call(
		memDC,
		ii.HbmColor,
		0,
		uintptr(h),
		uintptr(unsafe.Pointer(&pixels[0])),
		uintptr(unsafe.Pointer(&bih)),
		0,
	)
	if ret == 0 {
		return nil, errors.New("GetDIBits failed")
	}

	// Check if alpha channel has data (some icons have all-zero alpha).
	hasAlpha := false
	for i := 3; i < pixelCount; i += 4 {
		if pixels[i] != 0 {
			hasAlpha = true
			break
		}
	}

	// Convert BGRA → RGBA.
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for i := 0; i < pixelCount; i += 4 {
		img.Pix[i+0] = pixels[i+2] // R ← B
		img.Pix[i+1] = pixels[i+1] // G
		img.Pix[i+2] = pixels[i+0] // B ← R
		if hasAlpha {
			img.Pix[i+3] = pixels[i+3]
		} else {
			img.Pix[i+3] = 255
		}
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// resolveExePath attempts to build the full path to an application executable.
func resolveExePath(app AppInfo) string {
	if app.InstallPath != "" && app.ExeName != "" {
		full := filepath.Join(app.InstallPath, app.ExeName)
		if _, err := os.Stat(full); err == nil {
			return full
		}
	}
	return ""
}
