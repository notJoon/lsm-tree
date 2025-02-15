package lsm

import (
	"bytes"
)

type snapshot struct {
	records []*record
}

// Get retrieves a key's value at the snapshot point.
func (snap *snapshot) Get(key []byte) ([]byte, bool, error) {
	lo := 0
	hi := len(snap.records)
	for lo < hi {
		mid := (lo + hi) / 2
		if bytes.Compare(snap.records[mid].key, key) < 0 {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	if lo < len(snap.records) && bytes.Equal(snap.records[lo].key, key) {
		rec := snap.records[lo]
		if rec.deleted {
			return nil, false, nil
		}
		return rec.value, true, nil
	}
	return nil, false, nil
}

// Scan creates a range `Iterator` for the snapshot.
func (snap *snapshot) Scan(start, end []byte) Iterator {
	mt := &MemTable{
		records: snap.records,
	}
	idx := mt.findIndex(start)
	it := &memIterator{
		table: mt,
		index: idx,
		start: start,
		end:   end,
	}
	it.updateValidity()
	return it
}

// PrefixScan creates a prefix-based Iterator for the snapshot.
func (snap *snapshot) PrefixScan(prefix []byte) Iterator {
	start := prefix
	end := make([]byte, len(prefix))
	copy(end, prefix)
	for i := len(end) - 1; i >= 0; i-- {
		if end[i] != 0xff {
			end[i]++
			end = end[:i+1]
			break
		}
	}
	return snap.Scan(start, end)
}

func (snap *snapshot) Release() error {
	// no specific release needed for memory-based snapshot
	snap.records = nil
	return nil
}
