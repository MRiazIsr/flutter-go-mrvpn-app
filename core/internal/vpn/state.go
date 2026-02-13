package vpn

import "sync"

// State represents the VPN connection state.
type State string

const (
	StateDisconnected  State = "disconnected"
	StateConnecting    State = "connecting"
	StateConnected     State = "connected"
	StateDisconnecting State = "disconnecting"
	StateError         State = "error"
)

// StateListener is a callback invoked when VPN state changes.
type StateListener func(state State, err error)

// StatsListener is a callback invoked with traffic statistics updates.
type StatsListener func(upload, download, upSpeed, downSpeed int64)

// StateMachine manages VPN state transitions and notifies listeners.
type StateMachine struct {
	mu             sync.RWMutex
	state          State
	lastError      error
	stateListeners []StateListener
	statsListeners []StatsListener
}

// NewStateMachine creates a new state machine in disconnected state.
func NewStateMachine() *StateMachine {
	return &StateMachine{
		state: StateDisconnected,
	}
}

// State returns the current state.
func (sm *StateMachine) State() State {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.state
}

// LastError returns the last error.
func (sm *StateMachine) LastError() error {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.lastError
}

// SetState transitions to a new state and notifies listeners.
func (sm *StateMachine) SetState(s State, err error) {
	sm.mu.Lock()
	sm.state = s
	sm.lastError = err
	listeners := make([]StateListener, len(sm.stateListeners))
	copy(listeners, sm.stateListeners)
	sm.mu.Unlock()

	for _, l := range listeners {
		l(s, err)
	}
}

// OnStateChange registers a state change listener.
func (sm *StateMachine) OnStateChange(l StateListener) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.stateListeners = append(sm.stateListeners, l)
}

// OnStats registers a stats update listener.
func (sm *StateMachine) OnStats(l StatsListener) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.statsListeners = append(sm.statsListeners, l)
}

// NotifyStats notifies all stats listeners.
func (sm *StateMachine) NotifyStats(upload, download, upSpeed, downSpeed int64) {
	sm.mu.RLock()
	listeners := make([]StatsListener, len(sm.statsListeners))
	copy(listeners, sm.statsListeners)
	sm.mu.RUnlock()

	for _, l := range listeners {
		l(upload, download, upSpeed, downSpeed)
	}
}
