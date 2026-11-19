package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	listenAddr = ":8080"

	// maxLineLen caps a single protocol line so a peer cannot grow the read
	// buffer without bound.
	maxLineLen = 512

	maxNameLen = 32
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

// handleConnection serves one control connection. The registration lives as
// long as this connection does: when it drops, the peer is removed.
func handleConnection(conn net.Conn, reg *Registry) {
	defer conn.Close()

	// Keepalive so a device that vanishes without a FIN (phone sleeps, WiFi
	// drops) eventually tears the connection down instead of lingering in the
	// registry forever.
	if tcp, ok := conn.(*net.TCPConn); ok {
		tcp.SetKeepAlive(true)
		tcp.SetKeepAlivePeriod(30 * time.Second)
	}

	ip, _, err := net.SplitHostPort(conn.RemoteAddr().String())
	if err != nil {
		return
	}

	// Name this connection registered under, empty until REGISTER succeeds.
	var name string
	defer func() {
		if name != "" {
			reg.Remove(name)
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

		var err error
		switch strings.ToUpper(fields[0]) {
		case "REGISTER":
			name, err = doRegister(reg, reply, fields, ip, name)
		case "LOOKUP":
			err = doLookup(reg, reply, fields)
		case "LIST":
			err = doList(reg, reply, name)
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

// doRegister claims a name for this connection and returns the name now held,
// which is unchanged when the request is rejected.
func doRegister(reg *Registry, reply replyFunc, fields []string, ip, current string) (string, error) {
	if current != "" {
		return current, reply("ERR already-registered %s", current)
	}
	if len(fields) != 3 {
		return current, reply("ERR usage REGISTER <name> <listen-port>")
	}

	name, port := fields[1], fields[2]
	if !validName(name) {
		return current, reply("ERR bad-name")
	}
	if !validPort(port) {
		return current, reply("ERR bad-port")
	}

	if err := reg.Add(Peer{Name: name, IP: ip, Port: port}); err != nil {
		return current, reply("ERR name-taken")
	}
	return name, reply("OK %s", ip)
}

func doLookup(reg *Registry, reply replyFunc, fields []string) error {
	if len(fields) != 2 {
		return reply("ERR usage LOOKUP <name>")
	}

	p, ok := reg.Lookup(fields[1])
	if !ok {
		return reply("NOTFOUND %s", fields[1])
	}
	return reply("FOUND %s %s", p.Name, p.Addr())
}

func doList(reg *Registry, reply replyFunc, self string) error {
	peers := reg.List(self)

	parts := make([]string, 0, len(peers)+1)
	parts = append(parts, "PEERS")
	for _, p := range peers {
		parts = append(parts, fmt.Sprintf("%s:%s", p.Name, p.Addr()))
	}
	return reply("%s", strings.Join(parts, " "))
}

// validName keeps names short and free of the separators the protocol uses,
// so a reply line stays unambiguous to parse.
func validName(name string) bool {
	if name == "" || len(name) > maxNameLen {
		return false
	}
	for _, c := range name {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9':
		case c == '-', c == '_':
		default:
			return false
		}
	}
	return true
}

func validPort(port string) bool {
	n, err := strconv.Atoi(port)
	return err == nil && n > 0 && n <= 65535
}
