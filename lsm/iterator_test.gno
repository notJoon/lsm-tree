package lsm

import (
	"bytes"
	"testing"
)

func setupTestMemTable() *MemTable {
	mt := &MemTable{}
	// Insert records in sorted order
	data := []struct {
		key   []byte
		value []byte
	}{
		{[]byte("key1"), []byte("value1")},
		{[]byte("key3"), []byte("value3")},
		{[]byte("key5"), []byte("value5")},
		{[]byte("key7"), []byte("value7")},
		{[]byte("key9"), []byte("value9")},
	}

	for _, d := range data {
		mt.Put(d.key, d.value)
	}
	return mt
}

func TestMemIterator_Navigation(t *testing.T) {
	mt := setupTestMemTable()

	t.Run("Forward Iteration", func(t *testing.T) {
		it := &memIterator{
			table: mt,
			index: 0,
			valid: true,
		}

		expected := []string{"key1", "key3", "key5", "key7", "key9"}
		for i, exp := range expected {
			if !it.Valid() {
				t.Errorf("Iterator should be valid at position %d", i)
			}
			if !bytes.Equal(it.Key(), []byte(exp)) {
				t.Errorf("Expected key %s, got %s", exp, string(it.Key()))
			}
			it.Next()
		}
		if it.Valid() {
			t.Error("Iterator should be invalid after last element")
		}
	})

	t.Run("Backward Iteration", func(t *testing.T) {
		it := &memIterator{
			table: mt,
			index: len(mt.records) - 1,
			valid: true,
		}

		expected := []string{"key9", "key7", "key5", "key3", "key1"}
		for i, exp := range expected {
			if !it.Valid() {
				t.Errorf("Iterator should be valid at position %d", i)
			}
			if !bytes.Equal(it.Key(), []byte(exp)) {
				t.Errorf("Expected key %s, got %s", exp, string(it.Key()))
			}
			it.Prev()
		}
		if it.Valid() {
			t.Error("Iterator should be invalid after last element")
		}
	})
}

func TestMemIterator_Seek(t *testing.T) {
	mt := setupTestMemTable()

	testCases := []struct {
		name        string
		seekKey     []byte
		expectValid bool
		expectKey   []byte
	}{
		{
			name:        "Seek Existing",
			seekKey:     []byte("key3"),
			expectValid: true,
			expectKey:   []byte("key3"),
		},
		{
			name:        "Seek Between",
			seekKey:     []byte("key4"),
			expectValid: true,
			expectKey:   []byte("key5"),
		},
		{
			name:        "Seek Before All",
			seekKey:     []byte("key0"),
			expectValid: true,
			expectKey:   []byte("key1"),
		},
		{
			name:        "Seek After All",
			seekKey:     []byte("key99"),
			expectValid: false,
			expectKey:   nil,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			it := &memIterator{
				table: mt,
				valid: true,
			}

			it.Seek(tc.seekKey)

			if it.Valid() != tc.expectValid {
				t.Errorf("Expected valid=%v, got %v", tc.expectValid, it.Valid())
			}

			if !bytes.Equal(it.Key(), tc.expectKey) {
				t.Errorf("Expected key %s, got %s", string(tc.expectKey), string(it.Key()))
			}
		})
	}
}

func TestMemIterator_Range(t *testing.T) {
	mt := setupTestMemTable()

	t.Run("Valid Range", func(t *testing.T) {
		it := &memIterator{
			table: mt,
			start: []byte("key3"),
			end:   []byte("key7"),
			valid: true,
		}
		it.Seek(it.start)

		expected := []string{"key3", "key5"}
		for i, exp := range expected {
			if !it.Valid() {
				t.Errorf("Iterator should be valid at position %d", i)
			}
			if !bytes.Equal(it.Key(), []byte(exp)) {
				t.Errorf("Expected key %s, got %s", exp, string(it.Key()))
			}
			it.Next()
		}
	})

	t.Run("Empty Range", func(t *testing.T) {
		it := &memIterator{
			table: mt,
			start: []byte("key8"),
			end:   []byte("key85"),
			valid: true,
		}
		it.Seek(it.start)

		if it.Valid() {
			t.Error("Iterator should be invalid for empty range")
		}
	})
}

func TestMemIterator_DeletedRecords(t *testing.T) {
	mt := setupTestMemTable()
	mt.Delete([]byte("key3"))
	mt.Delete([]byte("key7"))

	t.Run("Forward Through Deleted", func(t *testing.T) {
		it := &memIterator{
			table: mt,
			valid: true,
		}
		it.Seek([]byte("key1"))

		expected := []string{"key1", "key5", "key9"}
		for i, exp := range expected {
			if !it.Valid() {
				t.Errorf("Iterator should be valid at position %d", i)
			}
			if !bytes.Equal(it.Key(), []byte(exp)) {
				t.Errorf("Expected key %s, got %s", exp, string(it.Key()))
			}
			it.Next()
		}
	})

	t.Run("Seek To Deleted", func(t *testing.T) {
		it := &memIterator{
			table: mt,
			valid: true,
		}
		it.Seek([]byte("key3"))

		if !it.Valid() {
			t.Error("Iterator should be valid")
		}
		if !bytes.Equal(it.Key(), []byte("key5")) {
			t.Errorf("Expected key key5, got %s", string(it.Key()))
		}
	})
}

func TestMemIterator_ValueAccess(t *testing.T) {
	mt := setupTestMemTable()
	mt.Delete([]byte("key3"))

	testCases := []struct {
		name        string
		seekKey     []byte
		expectValue []byte
	}{
		{
			name:        "Normal Value",
			seekKey:     []byte("key1"),
			expectValue: []byte("value1"),
		},
		{
			name:        "Deleted Value",
			seekKey:     []byte("key3"),
			expectValue: []byte("value5"), // Iterator moves to next valid record
		},
		{
			name:        "Invalid Position",
			seekKey:     []byte("key99"),
			expectValue: nil,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			it := &memIterator{
				table: mt,
				valid: true,
			}
			it.Seek(tc.seekKey)

			if !bytes.Equal(it.Value(), tc.expectValue) {
				t.Errorf("Expected value %s, got %s", string(tc.expectValue), string(it.Value()))
			}
		})
	}
}

func TestMemIterator_Close(t *testing.T) {
	mt := setupTestMemTable()
	it := &memIterator{
		table: mt,
		valid: true,
	}

	if err := it.Close(); err != nil {
		t.Errorf("Close returned error: %v", err)
	}
}
