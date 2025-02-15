package lsm

// LSMTree uses a single `MemTable` by default.
type LSMTree struct {
	memtable *MemTable
}

// NewLSMTree creates a new `LSMTree`.
func NewLSMTree() *LSMTree {
	return &LSMTree{
		memtable: &MemTable{
			records: make([]*record, 0),
		},
	}
}

// Get retrieves a value for the given key from the `MemTable`.
func (t *LSMTree) Get(key []byte) ([]byte, bool, error) {
	value, ok := t.memtable.Get(key)
	return value, ok, nil
}

// Put writes a key-value pair to the `MemTable`.
func (t *LSMTree) Put(key, value []byte) error {
	t.memtable.Put(key, value)
	return nil
}

// Delete marks an entry for the given key as deleted (tombstone).
func (t *LSMTree) Delete(key []byte) error {
	t.memtable.Delete(key)
	return nil
}

func (t *LSMTree) Scan(start, end []byte) Iterator {
	idx := t.memtable.findIndex(start)
	it := &memIterator{
		table: t.memtable,
		index: idx,
		start: start,
		end:   end,
	}
	it.updateValidity()
	return it
}

func (t *LSMTree) PrefixScan(prefix []byte) Iterator {
	// define prefix range as [prefix, prefix+1)
	start := prefix
	end := make([]byte, len(prefix))
	copy(end, prefix)

	// increment last byte (if not 0xff)
	for i := len(end) - 1; i >= 0; i-- {
		if end[i] != 0xff {
			end[i]++
			end = end[:i+1]
			break
		}
	}
	return t.Scan(start, end)
}

// CreateSnapshot creates a copy of the current memtable as a snapshot.
func (t *LSMTree) CreateSnapshot() Snapshot {
	recs := make([]*record, len(t.memtable.records))
	for i, rec := range t.memtable.records {
		recs[i] = &record{
			key:     cloneBytes(rec.key),
			value:   cloneBytes(rec.value),
			deleted: rec.deleted,
		}
	}
	return &snapshot{
		records: recs,
	}
}
