package main

import (
	"encoding/hex"
	"sync"
)

const idLen = 64

type Registry struct {
	mu    sync.RWMutex
	blobs map[string]map[string]string
}

func NewRegistry() *Registry {
	return &Registry{blobs: make(map[string]map[string]string)}
}

func (r *Registry) Publish(owner, recipient, blob string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	byRecipient, ok := r.blobs[owner]
	if !ok {
		byRecipient = make(map[string]string)
		r.blobs[owner] = byRecipient
	}
	byRecipient[recipient] = blob
}

func (r *Registry) Fetch(owner, recipient string) (string, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	blob, ok := r.blobs[owner][recipient]
	return blob, ok
}

func (r *Registry) RemoveOwner(owner string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	delete(r.blobs, owner)
}

func ValidID(id string) bool {
	if len(id) != idLen {
		return false
	}
	_, err := hex.DecodeString(id)
	return err == nil
}
