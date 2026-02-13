package main

import (
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/mriaz/vpn-core/internal/ipc"
	"github.com/mriaz/vpn-core/internal/service"
	"github.com/mriaz/vpn-core/internal/vpn"
)

func main() {
	installFlag := flag.Bool("install", false, "Install as Windows service")
	uninstallFlag := flag.Bool("uninstall", false, "Uninstall Windows service")
	interactiveFlag := flag.Bool("interactive", false, "Run in interactive (non-service) mode")
	flag.Parse()

	switch {
	case *installFlag:
		if err := service.Install(); err != nil {
			log.Fatalf("Failed to install service: %v", err)
		}
		log.Println("Service installed successfully. Start it with: net start MRVPN")
		return

	case *uninstallFlag:
		if err := service.Uninstall(); err != nil {
			log.Fatalf("Failed to uninstall service: %v", err)
		}
		log.Println("Service uninstalled successfully.")
		return

	case *interactiveFlag:
		log.Println("Running in interactive mode...")
		runCore(nil)
		return
	}

	// Default: try to run as Windows service
	if service.IsRunningAsService() {
		if err := service.RunAsService(func(stop <-chan struct{}) {
			runCore(stop)
		}); err != nil {
			log.Fatalf("Failed to run as service: %v", err)
		}
	} else {
		// Not a service, run interactively
		log.Println("Not running as service, starting in interactive mode...")
		log.Println("Use -install to install as a Windows service")
		runCore(nil)
	}
}

func runCore(stop <-chan struct{}) {
	// Initialize state machine
	sm := vpn.NewStateMachine()

	// Initialize VPN engine
	engine := vpn.NewEngine(sm)

	// Initialize IPC handler and server
	handler := ipc.NewHandler(engine, sm)
	server := ipc.NewServer(handler)

	// Set up state change notifications
	sm.OnStateChange(func(state vpn.State, err error) {
		errMsg := ""
		if err != nil {
			errMsg = err.Error()
		}
		server.Broadcast(&ipc.Notification{
			Method: "vpn.stateChanged",
			Params: ipc.StateChangedParams{
				State: string(state),
				Error: errMsg,
			},
		})
	})

	// Set up stats notifications
	sm.OnStats(func(upload, download, upSpeed, downSpeed int64) {
		server.Broadcast(&ipc.Notification{
			Method: "vpn.statsUpdate",
			Params: ipc.StatsUpdateParams{
				Upload:    upload,
				Download:  download,
				UpSpeed:   upSpeed,
				DownSpeed: downSpeed,
			},
		})
	})

	// Start IPC server
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start IPC server: %v", err)
	}
	defer server.Stop()
	defer engine.Disconnect()

	log.Println("MRVPN core service started")

	// Wait for stop signal
	if stop != nil {
		<-stop
	} else {
		// Interactive mode: wait for SIGINT/SIGTERM
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		<-sigChan
	}

	log.Println("MRVPN core service stopping...")
}
