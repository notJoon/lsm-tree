package lsm

import (
	"bytes"
)

type memIterator struct {
	table      *MemTable
	index      int
	start, end []byte
	valid      bool
	lastMove   string // "next" or "prev" to track direction
}

// updateValidity checks if the current index is valid and within range.
func (it *memIterator) updateValidity() {
	for {
		if it.index < 0 || it.index >= len(it.table.records) {
			it.valid = false
			return
		}

		rec := it.table.records[it.index]

		// Range check: start <= key < end
		if it.start != nil && bytes.Compare(rec.key, it.start) < 0 {
			it.valid = false
			return
		}
		if it.end != nil && bytes.Compare(rec.key, it.end) >= 0 {
			it.valid = false
			return
		}

		// Valid if not deleted
		if !rec.deleted {
			it.valid = true
			return
		}

		// Move to next or previous based on direction
		if it.lastMove == "prev" {
			it.index--
		} else {
			it.index++
		}
	}
}

func (it *memIterator) Next() {
	it.lastMove = "next"
	it.index++
	it.updateValidity()
}

func (it *memIterator) Prev() {
	it.lastMove = "prev"
	it.index--
	it.updateValidity()
}

func (it *memIterator) Seek(key []byte) {
	it.lastMove = "next" // Seek acts like a forward operation
	it.index = it.table.findIndex(key)
	it.updateValidity()
}

func (it *memIterator) Valid() bool {
	return it.valid
}

func (it *memIterator) Key() []byte {
	if it.Valid() {
		return it.table.records[it.index].key
	}
	return nil
}

func (it *memIterator) Value() []byte {
	if it.Valid() {
		rec := it.table.records[it.index]
		if rec.deleted {
			return nil
		}
		return rec.value
	}
	return nil
}

func (it *memIterator) Close() error {
	// no resources to release for in-memory iterator
	return nil
}
