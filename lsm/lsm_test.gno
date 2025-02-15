package lsm

import (
	"bytes"
	"testing"

	"gno.land/p/demo/ufmt"
)

func TestBasicOperations(t *testing.T) {
	tests := []struct {
		name     string
		ops      []operation
		wantErr  bool
		validate func(*testing.T, Map)
	}{
		{
			name: "simple put and get",
			ops: []operation{
				{op: "put", key: []byte("key1"), value: []byte("value1")},
				{op: "get", key: []byte("key1"), wantValue: []byte("value1"), wantOK: true},
			},
		},
		{
			name: "get non-existent key",
			ops: []operation{
				{op: "get", key: []byte("nonexistent"), wantOK: false},
			},
		},
		{
			name: "update existing key",
			ops: []operation{
				{op: "put", key: []byte("key1"), value: []byte("value1")},
				{op: "put", key: []byte("key1"), value: []byte("value2")},
				{op: "get", key: []byte("key1"), wantValue: []byte("value2"), wantOK: true},
			},
		},
		{
			name: "delete existing key",
			ops: []operation{
				{op: "put", key: []byte("key1"), value: []byte("value1")},
				{op: "delete", key: []byte("key1")},
				{op: "get", key: []byte("key1"), wantOK: false},
			},
		},
		{
			name: "delete non-existent key",
			ops: []operation{
				{op: "delete", key: []byte("nonexistent")},
				{op: "get", key: []byte("nonexistent"), wantOK: false},
			},
		},
		{
			name: "put after delete",
			ops: []operation{
				{op: "put", key: []byte("key1"), value: []byte("value1")},
				{op: "delete", key: []byte("key1")},
				{op: "put", key: []byte("key1"), value: []byte("value2")},
				{op: "get", key: []byte("key1"), wantValue: []byte("value2"), wantOK: true},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tree := NewLSMTree()
			runOperations(t, tree, tt.ops)
			if tt.validate != nil {
				tt.validate(t, tree)
			}
		})
	}
}

func TestScanOperations(t *testing.T) {
	tests := []struct {
		name     string
		setup    []operation
		scan     scanOperation
		wantKeys [][]byte
		wantVals [][]byte
	}{
		{
			name: "scan entire range",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "put", key: []byte("c"), value: []byte("3")},
			},
			scan: scanOperation{
				start: nil,
				end:   nil,
			},
			wantKeys: [][]byte{[]byte("a"), []byte("b"), []byte("c")},
			wantVals: [][]byte{[]byte("1"), []byte("2"), []byte("3")},
		},
		{
			name: "scan with range",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "put", key: []byte("c"), value: []byte("3")},
				{op: "put", key: []byte("d"), value: []byte("4")},
			},
			scan: scanOperation{
				start: []byte("b"),
				end:   []byte("d"),
			},
			wantKeys: [][]byte{[]byte("b"), []byte("c")},
			wantVals: [][]byte{[]byte("2"), []byte("3")},
		},
		{
			name: "scan with deleted items",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "delete", key: []byte("b")},
				{op: "put", key: []byte("c"), value: []byte("3")},
			},
			scan: scanOperation{
				start: nil,
				end:   nil,
			},
			wantKeys: [][]byte{[]byte("a"), []byte("c")},
			wantVals: [][]byte{[]byte("1"), []byte("3")},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tree := NewLSMTree()
			runOperations(t, tree, tt.setup)

			it := tree.Scan(tt.scan.start, tt.scan.end)
			defer it.Close()

			var keys, values [][]byte
			for it.Valid() {
				keys = append(keys, cloneBytes(it.Key()))
				values = append(values, cloneBytes(it.Value()))
				it.Next()
			}

			if !equalByteSlices(keys, tt.wantKeys) {
				t.Errorf("got keys %v, want %v", keys, tt.wantKeys)
			}
			if !equalByteSlices(values, tt.wantVals) {
				t.Errorf("got values %v, want %v", values, tt.wantVals)
			}
		})
	}
}

func TestPrefixScan(t *testing.T) {
	tests := []struct {
		name     string
		setup    []operation
		prefix   []byte
		wantKeys [][]byte
		wantVals [][]byte
	}{
		{
			name: "simple prefix",
			setup: []operation{
				{op: "put", key: []byte("abc1"), value: []byte("1")},
				{op: "put", key: []byte("abc2"), value: []byte("2")},
				{op: "put", key: []byte("def1"), value: []byte("3")},
			},
			prefix:   []byte("abc"),
			wantKeys: [][]byte{[]byte("abc1"), []byte("abc2")},
			wantVals: [][]byte{[]byte("1"), []byte("2")},
		},
		{
			name: "prefix with deleted items",
			setup: []operation{
				{op: "put", key: []byte("abc1"), value: []byte("1")},
				{op: "put", key: []byte("abc2"), value: []byte("2")},
				{op: "delete", key: []byte("abc1")},
				{op: "put", key: []byte("def1"), value: []byte("3")},
			},
			prefix:   []byte("abc"),
			wantKeys: [][]byte{[]byte("abc2")},
			wantVals: [][]byte{[]byte("2")},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tree := NewLSMTree()
			runOperations(t, tree, tt.setup)

			it := tree.PrefixScan(tt.prefix)
			defer it.Close()

			var keys, values [][]byte
			for it.Valid() {
				keys = append(keys, cloneBytes(it.Key()))
				values = append(values, cloneBytes(it.Value()))
				it.Next()
			}

			if !equalByteSlices(keys, tt.wantKeys) {
				t.Errorf("got keys %v, want %v", keys, tt.wantKeys)
			}
			if !equalByteSlices(values, tt.wantVals) {
				t.Errorf("got values %v, want %v", values, tt.wantVals)
			}
		})
	}
}

func TestIteratorPrevOperation(t *testing.T) {
	t.Skip("fix this test")
	tests := []struct {
		name      string
		setup     []operation
		actions   []string // sequence of "next" or "prev" operations
		wantKeys  [][]byte // expected keys after actions
		wantVals  [][]byte // expected values after actions
		scanStart []byte   // optional scan start
		scanEnd   []byte   // optional scan end
	}{
		{
			name: "basic prev navigation",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "put", key: []byte("c"), value: []byte("3")},
			},
			actions:  []string{"next", "next", "prev"},
			wantKeys: [][]byte{[]byte("b")},
			wantVals: [][]byte{[]byte("2")},
		},
		{
			name: "prev at start",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
			},
			actions:  []string{"prev"},
			wantKeys: [][]byte{},
			wantVals: [][]byte{},
		},
		{
			name: "prev with deleted items",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "put", key: []byte("c"), value: []byte("3")},
				{op: "delete", key: []byte("b")},
			},
			actions:  []string{"next", "next", "prev"},
			wantKeys: [][]byte{[]byte("a")},
			wantVals: [][]byte{[]byte("1")},
		},
		{
			name: "mixed next and prev",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "put", key: []byte("c"), value: []byte("3")},
				{op: "put", key: []byte("d"), value: []byte("4")},
			},
			actions:  []string{"next", "next", "next", "prev", "prev", "next"},
			wantKeys: [][]byte{[]byte("b")},
			wantVals: [][]byte{[]byte("2")},
		},
		{
			name: "prev with range scan",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "put", key: []byte("c"), value: []byte("3")},
				{op: "put", key: []byte("d"), value: []byte("4")},
			},
			scanStart: []byte("b"),
			scanEnd:   []byte("d"),
			actions:   []string{"next", "next", "prev"},
			wantKeys:  [][]byte{[]byte("b")},
			wantVals:  [][]byte{[]byte("2")},
		},
		{
			name: "prev at range boundaries",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "put", key: []byte("c"), value: []byte("3")},
			},
			scanStart: []byte("b"),
			scanEnd:   []byte("d"),
			actions:   []string{"prev"},
			wantKeys:  [][]byte{},
			wantVals:  [][]byte{},
		},
		{
			name: "alternating next/prev with deletions",
			setup: []operation{
				{op: "put", key: []byte("a"), value: []byte("1")},
				{op: "put", key: []byte("b"), value: []byte("2")},
				{op: "delete", key: []byte("c")},
				{op: "put", key: []byte("d"), value: []byte("4")},
				{op: "put", key: []byte("e"), value: []byte("5")},
			},
			actions:  []string{"next", "next", "next", "prev", "prev", "next", "next"},
			wantKeys: [][]byte{[]byte("d")},
			wantVals: [][]byte{[]byte("4")},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tree := NewLSMTree()
			runOperations(t, tree, tt.setup)

			var it Iterator
			if tt.scanStart != nil || tt.scanEnd != nil {
				it = tree.Scan(tt.scanStart, tt.scanEnd)
			} else {
				it = tree.Scan(nil, nil)
			}
			defer it.Close()

			// Execute the sequence of next/prev operations
			for _, action := range tt.actions {
				switch action {
				case "next":
					it.Next()
				case "prev":
					it.Prev()
				}
			}

			// Collect results
			var keys, values [][]byte
			if it.Valid() {
				keys = append(keys, cloneBytes(it.Key()))
				values = append(values, cloneBytes(it.Value()))
			}

			// Compare results
			if !equalByteSlices(keys, tt.wantKeys) {
				t.Errorf("got keys %v, want %v", keys, tt.wantKeys)
			}
			if !equalByteSlices(values, tt.wantVals) {
				t.Errorf("got values %v, want %v", values, tt.wantVals)
			}
		})
	}
}
