package ipc

import (
	"bufio"
	"encoding/json"
	"io"
	"log"
	"net"
	"sync"
	"time"

	"github.com/Microsoft/go-winio"
)

const maxClients = 10
const maxMessageSize = 1 * 1024 * 1024 // 1MB max message size

const pipeName = `\\.\pipe\MRVPN`

// Server is the named pipe IPC server.
type Server struct {
	handler        *Handler
	listener       net.Listener
	clients        map[net.Conn]bool
	mu             sync.Mutex
	done           chan struct{}
	hadClient      bool
	clientsDrained chan struct{}
}

// NewServer creates a new IPC server with the given handler.
func NewServer(handler *Handler) *Server {
	return &Server{
		handler:        handler,
		clients:        make(map[net.Conn]bool),
		done:           make(chan struct{}),
		clientsDrained: make(chan struct{}),
	}
}

// Start begins listening on the named pipe.
func (s *Server) Start() error {
	listener, err := winio.ListenPipe(pipeName, &winio.PipeConfig{
		SecurityDescriptor: "D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)", // SYSTEM + Admins + Interactive Users only
		MessageMode:        false,
		InputBufferSize:    65536,
		OutputBufferSize:   1048576, // 1MB — app list with icons can be large
	})
	if err != nil {
		return err
	}
	s.listener = listener

	go s.acceptLoop()
	log.Printf("IPC server listening on %s", pipeName)
	return nil
}

// Stop shuts down the IPC server.
func (s *Server) Stop() {
	close(s.done)
	if s.listener != nil {
		s.listener.Close()
	}
	s.mu.Lock()
	for conn := range s.clients {
		conn.Close()
	}
	s.mu.Unlock()
}

// Broadcast sends a notification to all connected clients.
func (s *Server) Broadcast(notification *Notification) {
	data, err := json.Marshal(notification)
	if err != nil {
		log.Printf("failed to marshal notification: %v", err)
		return
	}
	data = append(data, '\n')

	s.mu.Lock()
	defer s.mu.Unlock()

	var failed []net.Conn
	for conn := range s.clients {
		if _, err := conn.Write(data); err != nil {
			log.Printf("failed to send notification to client: %v", err)
			failed = append(failed, conn)
		}
	}
	for _, conn := range failed {
		delete(s.clients, conn)
		conn.Close()
	}
}

func (s *Server) acceptLoop() {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			select {
			case <-s.done:
				return
			default:
				log.Printf("accept error: %v", err)
				continue
			}
		}

		s.mu.Lock()
		if len(s.clients) >= maxClients {
			s.mu.Unlock()
			log.Printf("rejecting connection: max clients (%d) reached", maxClients)
			conn.Close()
			continue
		}
		s.clients[conn] = true
		s.hadClient = true
		s.mu.Unlock()

		go s.handleClient(conn)
	}
}

func (s *Server) handleClient(conn net.Conn) {
	defer func() {
		s.mu.Lock()
		delete(s.clients, conn)
		drained := len(s.clients) == 0 && s.hadClient
		s.mu.Unlock()
		conn.Close()
		if drained {
			log.Println("All IPC clients disconnected, signaling drain")
			select {
			case s.clientsDrained <- struct{}{}:
			default:
			}
		}
	}()

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 0, 64*1024), maxMessageSize)
	for scanner.Scan() {
		// Reset read deadline after each successful message
		conn.SetReadDeadline(time.Now().Add(5 * time.Minute))
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		var req Request
		if err := json.Unmarshal(line, &req); err != nil {
			resp := Response{
				Error: &RPCError{
					Code:    ErrCodeParseError,
					Message: "invalid JSON",
				},
			}
			s.sendResponse(conn, &resp)
			continue
		}

		resp := s.handler.Handle(&req)
		s.sendResponse(conn, resp)
	}
	if err := scanner.Err(); err != nil {
		if err != io.EOF {
			log.Printf("client read error: %v", err)
		}
	}
}

// ClientsDrained returns a channel that receives a signal when all clients
// have disconnected after at least one client was connected.
func (s *Server) ClientsDrained() <-chan struct{} {
	return s.clientsDrained
}

func (s *Server) sendResponse(conn net.Conn, resp *Response) {
	data, err := json.Marshal(resp)
	if err != nil {
		log.Printf("failed to marshal response: %v", err)
		return
	}
	data = append(data, '\n')
	if _, err := conn.Write(data); err != nil {
		log.Printf("failed to send response: %v", err)
	}
}
