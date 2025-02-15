package lsm

import (
	"bytes"
)

// record represents a single key-value entry.
type record struct {
	key     []byte
	value   []byte
	deleted bool // tombstone: true indicates a deleted record
}

// MemTable is a sorted slice of records.
type MemTable struct {
	records []*record
}

// findIndex finds the index for a key using binary search.
func (mt *MemTable) findIndex(key []byte) int {
	lo := 0
	hi := len(mt.records)

	for lo < hi {
		mid := (lo + hi) / 2
		if bytes.Compare(mt.records[mid].key, key) < 0 {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	return lo
}

// Get finds a record for the given key in the `MemTable`.
func (mt *MemTable) Get(key []byte) (value []byte, ok bool) {
	idx := mt.findIndex(key)
	if idx < len(mt.records) && bytes.Equal(mt.records[idx].key, key) {
		rec := mt.records[idx]
		if rec.deleted {
			return nil, false
		}
		return rec.value, true
	}
	return nil, false
}

// Put writes a new key-value pair into the `MemTable`.
func (mt *MemTable) Put(key, value []byte) {
	idx := mt.findIndex(key)
	if idx < len(mt.records) && bytes.Equal(mt.records[idx].key, key) {
		// update existing record
		mt.records[idx].value = cloneBytes(value)
		mt.records[idx].deleted = false
	} else {
		newRec := &record{
			key:   cloneBytes(key),
			value: cloneBytes(value),
		}
		mt.records = append(mt.records, nil)
		copy(mt.records[idx+1:], mt.records[idx:])
		mt.records[idx] = newRec
	}
}

// Delete marks a entry for the given key as a tombstone.
func (mt *MemTable) Delete(key []byte) {
	idx := mt.findIndex(key)
	if idx < len(mt.records) && bytes.Equal(mt.records[idx].key, key) {
		mt.records[idx].deleted = true
	} else {
		// insert a tombstone record if the key does not exist
		newRec := &record{
			key:     cloneBytes(key),
			deleted: true,
		}
		mt.records = append(mt.records, nil)
		copy(mt.records[idx+1:], mt.records[idx:])
		mt.records[idx] = newRec
	}
}

// cloneBytes creates a deep copy of a byte slice.
func cloneBytes(b []byte) []byte {
	if b == nil {
		return nil
	}

	cpy := make([]byte, len(b))
	copy(cpy, b)
	return cpy
}
