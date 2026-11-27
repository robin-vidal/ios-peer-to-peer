package main

import (
	"fmt"
	"strings"
	"testing"
)

func testID(n int) string {
	return fmt.Sprintf("%064x", n)
}

func TestPublishThenFetch(t *testing.T) {
	reg := NewRegistry()
	owner, recipient := testID(1), testID(2)

	if err := reg.Publish(owner, 1, recipient, "blob"); err != nil {
		t.Fatalf("publish: %v", err)
	}

	got, ok := reg.Fetch(owner, recipient)
	if !ok || got != "blob" {
		t.Fatalf("fetch returned %q, %v, want %q, true", got, ok, "blob")
	}
}

func TestFetchIsScopedToTheRecipient(t *testing.T) {
	reg := NewRegistry()
	owner, recipient, stranger := testID(1), testID(2), testID(3)

	if err := reg.Publish(owner, 1, recipient, "blob"); err != nil {
		t.Fatalf("publish: %v", err)
	}

	if _, ok := reg.Fetch(owner, stranger); ok {
		t.Fatal("a stranger fetched a blob published for someone else")
	}
	if _, ok := reg.Fetch(testID(4), recipient); ok {
		t.Fatal("fetch found a blob for an owner that published nothing")
	}
}

func TestPublishReplacesTheBlobForARecipient(t *testing.T) {
	reg := NewRegistry()
	owner, recipient := testID(1), testID(2)

	if err := reg.Publish(owner, 1, recipient, "old"); err != nil {
		t.Fatalf("publish: %v", err)
	}
	if err := reg.Publish(owner, 1, recipient, "new"); err != nil {
		t.Fatalf("publish: %v", err)
	}

	if got, _ := reg.Fetch(owner, recipient); got != "new" {
		t.Fatalf("fetch returned %q, want %q", got, "new")
	}
}

func TestRemoveConnDropsOnlyItsOwnBlobs(t *testing.T) {
	reg := NewRegistry()
	owner := testID(1)
	first, second := testID(2), testID(3)

	if err := reg.Publish(owner, 1, first, "from-conn-1"); err != nil {
		t.Fatalf("publish: %v", err)
	}
	if err := reg.Publish(owner, 2, second, "from-conn-2"); err != nil {
		t.Fatalf("publish: %v", err)
	}

	reg.RemoveConn(owner, 1)

	if _, ok := reg.Fetch(owner, first); ok {
		t.Fatal("the blob of the closed connection is still there")
	}
	if got, ok := reg.Fetch(owner, second); !ok || got != "from-conn-2" {
		t.Fatalf("the blob of the open connection is gone: %q, %v", got, ok)
	}
}

func TestOldConnectionClosingKeepsTheNewConnectionsBlob(t *testing.T) {
	reg := NewRegistry()
	owner, contact := testID(1), testID(2)

	if err := reg.Publish(owner, 1, contact, "wifi-address"); err != nil {
		t.Fatalf("publish on connection 1: %v", err)
	}
	if err := reg.Publish(owner, 2, contact, "cellular-address"); err != nil {
		t.Fatalf("publish on connection 2: %v", err)
	}

	reg.RemoveConn(owner, 1)

	got, ok := reg.Fetch(owner, contact)
	if !ok || got != "cellular-address" {
		t.Fatalf("after connection 1 closed, fetch returned %q, %v, want %q, true", got, ok, "cellular-address")
	}
}

func TestRemoveConnLeavesNoEmptyOwner(t *testing.T) {
	reg := NewRegistry()
	owner := testID(1)

	if err := reg.Publish(owner, 1, testID(2), "blob"); err != nil {
		t.Fatalf("publish: %v", err)
	}

	reg.RemoveConn(owner, 1)

	if _, ok := reg.blobs[owner]; ok {
		t.Fatal("an owner with no blob left is still in the registry")
	}
}

func TestRemoveConnOnAnUnknownOwnerDoesNothing(t *testing.T) {
	reg := NewRegistry()

	reg.RemoveConn(testID(1), 1)

	if len(reg.blobs) != 0 {
		t.Fatal("removing an unknown owner created an entry")
	}
}

func TestRecipientCapIsPerOwnerAcrossConnections(t *testing.T) {
	reg := NewRegistry()
	owner := testID(1)

	for i := 0; i < maxBlobsPerOwner; i++ {
		conn := uint64(1 + i%2)
		if err := reg.Publish(owner, conn, testID(100+i), "blob"); err != nil {
			t.Fatalf("publish %d: %v", i, err)
		}
	}

	if err := reg.Publish(owner, 3, testID(1000), "blob"); err != errTooManyRecipients {
		t.Fatalf("a new recipient past the cap returned %v, want %v", err, errTooManyRecipients)
	}

	if err := reg.Publish(owner, 3, testID(100), "replacement"); err != nil {
		t.Fatalf("replacing an existing recipient at the cap failed: %v", err)
	}
}

func TestValidID(t *testing.T) {
	cases := []struct {
		name string
		id   string
		want bool
	}{
		{"64 hex characters", testID(1), true},
		{"too short", strings.Repeat("a", idLen-1), false},
		{"too long", strings.Repeat("a", idLen+1), false},
		{"not hexadecimal", strings.Repeat("g", idLen), false},
		{"empty", "", false},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := ValidID(c.id); got != c.want {
				t.Fatalf("ValidID(%q) = %v, want %v", c.id, got, c.want)
			}
		})
	}
}
