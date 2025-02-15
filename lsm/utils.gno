package lsm

import (
	"bytes"
	"testing"

	"gno.land/p/demo/ufmt"
)

type operation struct {
	op        string
	key       []byte
	value     []byte
	wantValue []byte
	wantOK    bool
}

type scanOperation struct {
	start []byte
	end   []byte
}

func runOperations(t *testing.T, tree Map, ops []operation) {
	t.Helper()
	for i, op := range ops {
		if err := runOperation(t, tree, op); err != nil {
			t.Fatalf("operation %d failed: %v", i, err)
		}
	}
}

func runOperation(t *testing.T, tree Map, op operation) error {
	t.Helper()
	switch op.op {
	case "put":
		return tree.Put(op.key, op.value)
	case "delete":
		return tree.Delete(op.key)
	case "get":
		value, ok, err := tree.Get(op.key)
		if err != nil {
			return err
		}
		if ok != op.wantOK {
			return ufmt.Errorf("get %q: got ok=%v, want %v", op.key, ok, op.wantOK)
		}
		if ok && !bytes.Equal(value, op.wantValue) {
			return ufmt.Errorf("get %q: got value=%q, want %q", op.key, value, op.wantValue)
		}
	}
	return nil
}

func equalByteSlices(a, b [][]byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if !bytes.Equal(a[i], b[i]) {
			return false
		}
	}
	return true
}
