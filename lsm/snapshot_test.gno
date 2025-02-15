package lsm

import (
	"bytes"
	"testing"
)

func TestSnapshot(t *testing.T) {
	tests := []struct {
		name          string
		setup         []operation
		snapshotAfter int // Take snapshot after N operations
		postSnapshot  []operation
		validate      func(*testing.T, Snapshot, Map)
	}{
		{
			name: "snapshot basic operations",
			setup: []operation{
				{op: "put", key: []byte("key1"), value: []byte("value1")},
				{op: "put", key: []byte("key2"), value: []byte("value2")},
			},
			snapshotAfter: 2,
			postSnapshot: []operation{
				{op: "put", key: []byte("key1"), value: []byte("value1_new")},
				{op: "delete", key: []byte("key2")},
			},
			validate: func(t *testing.T, snap Snapshot, tree Map) {
				// Check snapshot state
				val1, ok, _ := snap.Get([]byte("key1"))
				if !ok || !bytes.Equal(val1, []byte("value1")) {
					t.Errorf("snapshot: got (%v, %v) for key1, want (value1, true)", val1, ok)
				}

				val2, ok, _ := snap.Get([]byte("key2"))
				if !ok || !bytes.Equal(val2, []byte("value2")) {
					t.Errorf("snapshot: got (%v, %v) for key2, want (value2, true)", val2, ok)
				}

				// Check current state
				val1, ok, _ = tree.Get([]byte("key1"))
				if !ok || !bytes.Equal(val1, []byte("value1_new")) {
					t.Errorf("current: got (%v, %v) for key1, want (value1_new, true)", val1, ok)
				}

				val2, ok, _ = tree.Get([]byte("key2"))
				if ok {
					t.Errorf("current: got (%v, %v) for key2, want (nil, false)", val2, ok)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tree := NewLSMTree()

			// Run setup operations
			for i, op := range tt.setup {
				if err := runOperation(t, tree, op); err != nil {
					t.Fatalf("setup operation %d failed: %v", i, err)
				}
			}

			// Create snapshot
			snap := tree.CreateSnapshot()
			defer snap.Release()

			// Run post-snapshot operations
			for i, op := range tt.postSnapshot {
				if err := runOperation(t, tree, op); err != nil {
					t.Fatalf("post-snapshot operation %d failed: %v", i, err)
				}
			}

			if tt.validate != nil {
				tt.validate(t, snap, tree)
			}
		})
	}
}
