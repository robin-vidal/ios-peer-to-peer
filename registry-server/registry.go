package main

import (
	"errors"
	"net"
	"sort"
	"sync"
)

// ErrNameTaken is returned when a peer registers a name another live
// connection already holds.
var ErrNameTaken = errors.New("name taken")

// Peer is a registered device. IP is what the server observed on the
// control connection; Port is the one the device listens on for direct
// peer-to-peer traffic.
type Peer struct {
	Name string
	IP   string
	Port string
}

// Addr is the endpoint other peers dial.
func (p Peer) Addr() string {
	return net.JoinHostPort(p.IP, p.Port)
}

// Registry maps names to peers. Safe for concurrent use.
type Registry struct {
	mu    sync.RWMutex
	peers map[string]Peer
}

func NewRegistry() *Registry {
	return &Registry{peers: make(map[string]Peer)}
}

func (r *Registry) Add(p Peer) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.peers[p.Name]; exists {
		return ErrNameTaken
	}
	r.peers[p.Name] = p
	return nil
}

func (r *Registry) Remove(name string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	delete(r.peers, name)
}

func (r *Registry) Lookup(name string) (Peer, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	p, ok := r.peers[name]
	return p, ok
}

// List returns every peer except the caller, sorted by name so clients get a
// stable ordering. Pass an empty string to list everyone.
func (r *Registry) List(except string) []Peer {
	r.mu.RLock()
	defer r.mu.RUnlock()

	out := make([]Peer, 0, len(r.peers))
	for name, p := range r.peers {
		if name == except {
			continue
		}
		out = append(out, p)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}
