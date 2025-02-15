package lsm

// Map interface provides basic functionality for an LSM tree.
// (Since generics are not supported in this environment, keys and values are defined as []byte type)
type Map interface {
	// Get returns the value for the given key.
	// If the key does not exist, ok will be false.
	Get(key []byte) (value []byte, ok bool, err error)

	// Put stores the key-value pair.
	Put(key, value []byte) error

	// Delete removes the entry for the given key.
	Delete(key []byte) error

	// Scan returns an Iterator that traverses entries from start to end.
	// If start is nil, iteration begins from the beginning; if end is nil, continues until the end.
	Scan(start, end []byte) Iterator

	// PrefixScan returns an Iterator that traverses entries with the given prefix.
	PrefixScan(prefix []byte) Iterator

	// CreateSnapshot creates and returns an MVCC snapshot of the current state.
	CreateSnapshot() Snapshot
}

// Iterator interface provides traversal functionality.
// Traversal direction can be forward using Next() or reverse using Prev().
type Iterator interface {
	// Valid returns whether the current iterator position is valid.
	Valid() bool

	// Key returns the key at the current position.
	Key() []byte

	// Value returns the value at the current position.
	Value() []byte

	// Next moves the iterator to the next entry.
	Next()

	// Prev moves the iterator to the previous entry.
	Prev()

	// Seek moves the iterator to the given key or the next closest position.
	Seek(key []byte)

	// Close releases resources used by the iterator.
	Close() error
}

// Snapshot interface provides MVCC snapshot functionality.
// When a snapshot is created, it allows reading data as of the creation time,
// and subsequent changes are not reflected.
type Snapshot interface {
	// Get returns the value for the given key at the snapshot point.
	Get(key []byte) (value []byte, ok bool, err error)

	// Scan returns an Iterator that traverses entries from start to end at the snapshot point.
	Scan(start, end []byte) Iterator

	// PrefixScan returns an Iterator that traverses entries with the given prefix at the snapshot point.
	PrefixScan(prefix []byte) Iterator

	// Release releases resources used by the snapshot.
	Release() error
}
