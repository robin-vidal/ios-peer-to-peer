package main

import (
	"bufio"
	"encoding/base64"
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

const (
	listenAddr = ":8080"

	maxLineLen = 2048

	maxBlobLen = 1024
)

func main() {
	reg := NewRegistry()

	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "server: unable to listen on %s: %v\n", listenAddr, err)
		os.Exit(1)
	}
	fmt.Printf("server: listening on %s\n", listenAddr)

	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Fprintf(os.Stderr, "server: unable to accept: %v\n", err)
			continue
		}
		go handleConnection(conn, reg)
	}
}

func handleConnection(conn net.Conn, reg *Registry) {
	defer conn.Close()

	if tcp, ok := conn.(*net.TCPConn); ok {
		tcp.SetKeepAlive(true)
		tcp.SetKeepAlivePeriod(30 * time.Second)
	}

	var h handshake
	defer func() {
		if h.id != "" {
			reg.RemoveOwner(h.id)
		}
	}()

	w := bufio.NewWriter(conn)
	reply := func(format string, args ...any) error {
		fmt.Fprintf(w, format+"\n", args...)
		return w.Flush()
	}

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
			err = h.hello(reply, fields)
		case "AUTH":
			err = h.auth(reply, fields)
		case "PUBLISH":
			err = doPublish(reg, reply, fields, h.id)
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

func doPublish(reg *Registry, reply replyFunc, fields []string, owner string) error {
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

	reg.Publish(owner, recipient, blob)
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
