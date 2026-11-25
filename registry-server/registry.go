package main

import (
	"encoding/hex"
	"errors"
	"sync"
)

const (
	idLen = 64

	maxBlobsPerOwner = 64
)

var errTooManyRecipients = errors.New("too-many-recipients")

type entry struct {
	blob string
	conn uint64
}

type Registry struct {
	mu    sync.RWMutex
	blobs map[string]map[string]entry
}

func NewRegistry() *Registry {
	return &Registry{blobs: make(map[string]map[string]entry)}
}

func (r *Registry) Publish(owner string, conn uint64, recipient, blob string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	byRecipient, ok := r.blobs[owner]
	if ok {
		_, exists := byRecipient[recipient]
		if !exists && len(byRecipient) >= maxBlobsPerOwner {
			return errTooManyRecipients
		}
	} else {
		byRecipient = make(map[string]entry)
		r.blobs[owner] = byRecipient
	}

	byRecipient[recipient] = entry{blob: blob, conn: conn}
	return nil
}

func (r *Registry) Fetch(owner, recipient string) (string, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	e, ok := r.blobs[owner][recipient]
	return e.blob, ok
}

func (r *Registry) RemoveConn(owner string, conn uint64) {
	r.mu.Lock()
	defer r.mu.Unlock()

	byRecipient, ok := r.blobs[owner]
	if !ok {
		return
	}

	for recipient, e := range byRecipient {
		if e.conn == conn {
			delete(byRecipient, recipient)
		}
	}

	if len(byRecipient) == 0 {
		delete(r.blobs, owner)
	}
}

func ValidID(id string) bool {
	if len(id) != idLen {
		return false
	}
	_, err := hex.DecodeString(id)
	return err == nil
}