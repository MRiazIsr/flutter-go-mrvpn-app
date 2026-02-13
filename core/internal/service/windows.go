package service

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/eventlog"
	"golang.org/x/sys/windows/svc/mgr"
)

const serviceName = "MRVPN"
const serviceDisplay = "MRVPN Service"
const serviceDescription = "MRVPN backend service - manages VPN connections via sing-box"

// RunFunc is the function called when the service starts.
type RunFunc func(stop <-chan struct{})

// MriazService implements the Windows service interface.
type MriazService struct {
	run RunFunc
}

// Execute implements svc.Handler.
func (s *MriazService) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (ssec bool, errno uint32) {
	changes <- svc.Status{State: svc.StartPending}

	stop := make(chan struct{})
	go s.run(stop)

	changes <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}

	for c := range r {
		switch c.Cmd {
		case svc.Interrogate:
			changes <- c.CurrentStatus
		case svc.Stop, svc.Shutdown:
			changes <- svc.Status{State: svc.StopPending}
			close(stop)
			return
		}
	}
	return
}

// RunAsService runs the given function as a Windows service.
func RunAsService(run RunFunc) error {
	elog, err := eventlog.Open(serviceName)
	if err == nil {
		defer elog.Close()
	}

	return svc.Run(serviceName, &MriazService{run: run})
}

// IsRunningAsService detects if we're running as a Windows service.
func IsRunningAsService() bool {
	isService, err := svc.IsWindowsService()
	if err != nil {
		return false
	}
	return isService
}

// Install installs the service in Windows Service Manager.
func Install() error {
	exePath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get executable path: %w", err)
	}
	exePath, err = filepath.Abs(exePath)
	if err != nil {
		return fmt.Errorf("failed to get absolute path: %w", err)
	}

	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("failed to connect to service manager: %w", err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(serviceName)
	if err == nil {
		s.Close()
		return fmt.Errorf("service %s already exists", serviceName)
	}

	s, err = m.CreateService(serviceName, exePath, mgr.Config{
		DisplayName: serviceDisplay,
		Description: serviceDescription,
		StartType:   mgr.StartAutomatic,
	}, "service")
	if err != nil {
		return fmt.Errorf("failed to create service: %w", err)
	}
	defer s.Close()

	// Set up event logging
	if err := eventlog.InstallAsEventCreate(serviceName, eventlog.Error|eventlog.Warning|eventlog.Info); err != nil {
		log.Printf("warning: failed to set up event logging: %v", err)
	}

	log.Printf("service %s installed successfully", serviceName)
	return nil
}

// Uninstall removes the service from Windows Service Manager.
func Uninstall() error {
	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("failed to connect to service manager: %w", err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(serviceName)
	if err != nil {
		return fmt.Errorf("service %s not found: %w", serviceName, err)
	}
	defer s.Close()

	// Stop if running
	status, err := s.Query()
	if err == nil && status.State != svc.Stopped {
		_, _ = s.Control(svc.Stop)
		// Wait a bit for stop
		time.Sleep(2 * time.Second)
	}

	if err := s.Delete(); err != nil {
		return fmt.Errorf("failed to delete service: %w", err)
	}

	_ = eventlog.Remove(serviceName)

	log.Printf("service %s uninstalled successfully", serviceName)
	return nil
}

// Start starts the Windows service.
func Start() error {
	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("failed to connect to service manager: %w", err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(serviceName)
	if err != nil {
		return fmt.Errorf("service %s not found: %w", serviceName, err)
	}
	defer s.Close()

	return s.Start()
}

// Stop stops the Windows service.
func Stop() error {
	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("failed to connect to service manager: %w", err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(serviceName)
	if err != nil {
		return fmt.Errorf("service %s not found: %w", serviceName, err)
	}
	defer s.Close()

	_, err = s.Control(svc.Stop)
	return err
}
