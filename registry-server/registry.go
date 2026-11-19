package main

import (
	"errors"
	"net"
	"sort"
	"sync"
)

var ErrNameTaken = errors.New("name taken")

type Peer struct {
	Name string
	IP   string
	Port string
}

func (p Peer) Addr() string {
	return net.JoinHostPort(p.IP, p.Port)
}

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
