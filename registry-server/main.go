package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"net"
	"os"
	"strings"
	"sync/atomic"
	"time"
)

const (
	defaultAddr = ":8080"
	defaultCert = "server.crt"
	defaultKey  = "server.key"

	keepAlivePeriod = 30 * time.Second

	authTimeout  = 10 * time.Second
	writeTimeout = 10 * time.Second

	maxConns = 1024

	maxHandshakes = 10

	maxLineLen = 2048

	maxBlobLen = 1024
)

func env(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}

func main() {
	addr := env("REGISTRY_ADDR", defaultAddr)
	certPath := env("REGISTRY_TLS_CERT", defaultCert)
	keyPath := env("REGISTRY_TLS_KEY", defaultKey)

	cert, err := tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "server: unable to load certificate %s and key %s: %v\n", certPath, keyPath, err)
		os.Exit(1)
	}

	lc := net.ListenConfig{KeepAlive: keepAlivePeriod}
	base, err := lc.Listen(context.Background(), "tcp", addr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "server: unable to listen on %s: %v\n", addr, err)
		os.Exit(1)
	}

	ln := tls.NewListener(base, &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS13,
	})

	reg := NewRegistry()

	fmt.Printf("server: listening on %s\n", addr)

	slots := make(chan struct{}, maxConns)

	var nextConn atomic.Uint64

	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Fprintf(os.Stderr, "server: unable to accept: %v\n", err)
			continue
		}

		select {
		case slots <- struct{}{}:
			connID := nextConn.Add(1)
			go func() {
				defer func() { <-slots }()
				handleConnection(conn, reg, connID)
			}()
		default:
			conn.Close()
		}
	}
}

func handleConnection(conn net.Conn, reg *Registry, connID uint64) {
	defer conn.Close()

	if err := conn.SetDeadline(time.Now().Add(authTimeout)); err != nil {
		return
	}

	var h handshake
	defer func() {
		if h.id != "" {
			reg.RemoveConn(h.id, connID)
		}
	}()

	w := bufio.NewWriter(conn)
	reply := func(format string, args ...any) error {
		if err := conn.SetWriteDeadline(time.Now().Add(writeTimeout)); err != nil {
			return err
		}
		fmt.Fprintf(w, format+"\n", args...)
		return w.Flush()
	}

	handshakes := 0

	sc := bufio.NewScanner(conn)
	sc.Buffer(make([]byte, 0, 256), maxLineLen)

	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) == 0 {
			continue
		}

		cmd := strings.ToUpper(fields[0])
		if !h.authed && cmd != "HELLO" && cmd != "AUTH" && cmd != "QUIT" {
			if err := reply("ERR unauthenticated"); err != nil {
				return
			}
			continue
		}

		var err error
		switch cmd {
		case "HELLO":
			handshakes++
			if handshakes > maxHandshakes {
				reply("ERR too-many-handshakes")
				return
			}
			err = h.hello(reply, fields)
		case "AUTH":
			err = h.auth(reply, fields)
			if h.authed {
				if clearErr := conn.SetReadDeadline(time.Time{}); clearErr != nil {
					return
				}
			}
		case "PUBLISH":
			err = doPublish(reg, reply, fields, h.id, connID)
		case "FETCH":
			err = doFetch(reg, reply, fields, h.id)
		case "QUIT":
			reply("BYE")
			return
		default:
			err = reply("ERR unknown-command")
		}
		if err != nil {
			return
		}
	}
}

type replyFunc func(format string, args ...any) error

func doPublish(reg *Registry, reply replyFunc, fields []string, owner string, connID uint64) error {
	if len(fields) != 3 {
		return reply("ERR usage PUBLISH <recipient-id> <blob-b64>")
	}

	recipient := strings.ToLower(fields[1])
	if !ValidID(recipient) {
		return reply("ERR bad-id")
	}

	blob := fields[2]
	if len(blob) > maxBlobLen {
		return reply("ERR blob-too-large")
	}
	if _, err := base64.StdEncoding.DecodeString(blob); err != nil {
		return reply("ERR bad-blob")
	}

	if err := reg.Publish(owner, connID, recipient, blob); err != nil {
		return reply("ERR %s", err)
	}
	return reply("OK")
}

func doFetch(reg *Registry, reply replyFunc, fields []string, requester string) error {
	if len(fields) != 2 {
		return reply("ERR usage FETCH <owner-id>")
	}

	owner := strings.ToLower(fields[1])
	if !ValidID(owner) {
		return reply("ERR bad-id")
	}

	blob, ok := reg.Fetch(owner, requester)
	if !ok {
		return reply("NOTFOUND %s", owner)
	}
	return reply("BLOB %s %s", owner, blob)
}
