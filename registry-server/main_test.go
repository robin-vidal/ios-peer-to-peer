package main

import (
	"bufio"
	"encoding/base64"
	"io"
	"net"
	"strings"
	"testing"
	"time"
)

const testTimeout = 2 * time.Second

type testConn struct {
	client net.Conn
	lines  *bufio.Reader
	done   chan struct{}
}

func startConn(t *testing.T, reg *Registry, connID uint64) *testConn {
	t.Helper()

	server, client := net.Pipe()
	done := make(chan struct{})
	go func() {
		handleConnection(server, reg, connID)
		close(done)
	}()

	c := &testConn{client: client, lines: bufio.NewReader(client), done: done}
	t.Cleanup(c.close)
	return c
}

func (c *testConn) close() {
	c.client.Close()
	<-c.done
}

func (c *testConn) send(t *testing.T, line string) string {
	t.Helper()

	if err := c.client.SetDeadline(time.Now().Add(testTimeout)); err != nil {
		t.Fatalf("unable to set a deadline: %v", err)
	}
	if _, err := io.WriteString(c.client, line+"\n"); err != nil {
		t.Fatalf("unable to send %q: %v", line, err)
	}
	reply, err := c.lines.ReadString('\n')
	if err != nil {
		t.Fatalf("no reply to %q: %v", line, err)
	}
	return strings.TrimSuffix(reply, "\n")
}

func (c *testConn) authenticate(t *testing.T, ti testIdentity) string {
	t.Helper()

	signPub, boxPub := ti.encoded()
	challenge := c.send(t, "HELLO "+signPub+" "+boxPub)

	fields := strings.Fields(challenge)
	if len(fields) != 2 || fields[0] != "CHALLENGE" {
		t.Fatalf("HELLO returned %q, want CHALLENGE <nonce>", challenge)
	}
	nonce, err := base64.StdEncoding.DecodeString(fields[1])
	if err != nil {
		t.Fatalf("the challenge is not base64: %v", err)
	}

	ok := strings.Fields(c.send(t, "AUTH "+ti.sign(t, nonce)))
	if len(ok) != 2 || ok[0] != "OK" {
		t.Fatalf("AUTH returned %q, want OK <id>", strings.Join(ok, " "))
	}
	return ok[1]
}

func TestCommandsBeforeAuthAreRefused(t *testing.T) {
	c := startConn(t, NewRegistry(), 1)

	for _, line := range []string{
		"PUBLISH " + testID(2) + " YmxvYg==",
		"FETCH " + testID(2),
		"SOMETHING",
	} {
		if got := c.send(t, line); got != "ERR unauthenticated" {
			t.Fatalf("%q before AUTH returned %q, want %q", line, got, "ERR unauthenticated")
		}
	}
}

func TestUnknownCommandAfterAuth(t *testing.T) {
	c := startConn(t, NewRegistry(), 1)
	c.authenticate(t, newTestIdentity(t))

	if got := c.send(t, "SOMETHING"); got != "ERR unknown-command" {
		t.Fatalf("an unknown command returned %q, want %q", got, "ERR unknown-command")
	}
}

func TestOverLongLineClosesTheConnection(t *testing.T) {
	c := startConn(t, NewRegistry(), 1)

	if err := c.client.SetDeadline(time.Now().Add(testTimeout)); err != nil {
		t.Fatalf("unable to set a deadline: %v", err)
	}

	go io.WriteString(c.client, strings.Repeat("a", maxLineLen+1)+"\n")

	select {
	case <-c.done:
	case <-time.After(testTimeout):
		t.Fatal("the server kept the connection open after an over-long line")
	}

	if _, err := c.lines.ReadString('\n'); err == nil {
		t.Fatal("the server replied to an over-long line instead of closing")
	}
}

func TestClosingTheOldConnectionKeepsTheNewConnectionsBlob(t *testing.T) {
	reg := NewRegistry()
	me := newTestIdentity(t)
	contact := testID(2)

	old := startConn(t, reg, 1)
	id := old.authenticate(t, me)
	if got := old.send(t, "PUBLISH "+contact+" b2xk"); got != "OK" {
		t.Fatalf("publish on the old connection returned %q", got)
	}

	current := startConn(t, reg, 2)
	current.authenticate(t, me)
	if got := current.send(t, "PUBLISH "+contact+" bmV3"); got != "OK" {
		t.Fatalf("publish on the new connection returned %q", got)
	}

	old.close()

	blob, ok := reg.Fetch(id, contact)
	if !ok || blob != "bmV3" {
		t.Fatalf("after the old connection closed, the blob is %q, %v, want %q, true", blob, ok, "bmV3")
	}
}
