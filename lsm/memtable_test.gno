package lsm

import (
	"bytes"
	"testing"
)

func TestMemTable_Put(t *testing.T) {
	mt := &MemTable{}

	// Test inserting new records
	tests := []struct {
		key   []byte
		value []byte
	}{
		{[]byte("key1"), []byte("value1")},
		{[]byte("key2"), []byte("value2")},
		{[]byte("key3"), []byte("value3")},
	}

	for _, tt := range tests {
		mt.Put(tt.key, tt.value)
		value, ok := mt.Get(tt.key)
		if !ok {
			t.Errorf("Failed to get key %s after Put", tt.key)
		}
		if !bytes.Equal(value, tt.value) {
			t.Errorf("Got wrong value for key %s: expected %s, got %s", tt.key, tt.value, value)
		}
	}

	// Test updating existing record
	newValue := []byte("updated_value1")
	mt.Put([]byte("key1"), newValue)
	value, ok := mt.Get([]byte("key1"))
	if !ok {
		t.Error("Failed to get key after update")
	}
	if !bytes.Equal(value, newValue) {
		t.Errorf("Got wrong value after update: expected %s, got %s", newValue, value)
	}

	// Test records are sorted
	for i := 1; i < len(mt.records); i++ {
		if bytes.Compare(mt.records[i-1].key, mt.records[i].key) >= 0 {
			t.Error("Records are not properly sorted")
		}
	}
}

func TestMemTable_Get(t *testing.T) {
	mt := &MemTable{}

	// Test getting non-existent key
	value, ok := mt.Get([]byte("nonexistent"))
	if ok {
		t.Error("Get succeeded for non-existent key")
	}
	if value != nil {
		t.Error("Get returned non-nil value for non-existent key")
	}

	// Insert and get
	key := []byte("test_key")
	val := []byte("test_value")
	mt.Put(key, val)

	value, ok = mt.Get(key)
	if !ok {
		t.Error("Get failed for existing key")
	}
	if !bytes.Equal(value, val) {
		t.Errorf("Got wrong value: expected %s, got %s", val, value)
	}

	// Test getting deleted key
	mt.Delete(key)
	value, ok = mt.Get(key)
	if ok {
		t.Error("Get succeeded for deleted key")
	}
	if value != nil {
		t.Error("Get returned non-nil value for deleted key")
	}
}

func TestMemTable_Delete(t *testing.T) {
	mt := &MemTable{}

	// Test deleting non-existent key
	mt.Delete([]byte("nonexistent"))
	if len(mt.records) != 1 {
		t.Error("Delete didn't create tombstone for non-existent key")
	}
	if !mt.records[0].deleted {
		t.Error("Record not marked as deleted")
	}

	// Test deleting existing key
	key := []byte("test_key")
	val := []byte("test_value")
	mt.Put(key, val)
	mt.Delete(key)

	value, ok := mt.Get(key)
	if ok {
		t.Error("Get succeeded for deleted key")
	}
	if value != nil {
		t.Error("Get returned non-nil value for deleted key")
	}

	// Test putting after delete
	mt.Put(key, val)
	value, ok = mt.Get(key)
	if !ok {
		t.Error("Get failed after putting deleted key")
	}
	if !bytes.Equal(value, val) {
		t.Errorf("Got wrong value after putting deleted key: expected %s, got %s", val, value)
	}
}

func TestMemTable_EmptyKeyValue(t *testing.T) {
	mt := &MemTable{}

	// Test empty key
	mt.Put([]byte{}, []byte("empty_key"))
	value, ok := mt.Get([]byte{})
	if !ok {
		t.Error("Failed to get empty key")
	}
	if !bytes.Equal(value, []byte("empty_key")) {
		t.Error("Got wrong value for empty key")
	}

	// Test nil key
	mt.Put(nil, []byte("nil_key"))
	value, ok = mt.Get(nil)
	if !ok {
		t.Error("Failed to get nil key")
	}
	if !bytes.Equal(value, []byte("nil_key")) {
		t.Error("Got wrong value for nil key")
	}

	// Test empty value
	mt.Put([]byte("empty_value"), []byte{})
	value, ok = mt.Get([]byte("empty_value"))
	if !ok {
		t.Error("Failed to get key with empty value")
	}
	if !bytes.Equal(value, []byte{}) {
		t.Error("Got wrong value for empty value")
	}

	// Test nil value
	mt.Put([]byte("nil_value"), nil)
	value, ok = mt.Get([]byte("nil_value"))
	if !ok {
		t.Error("Failed to get key with nil value")
	}
	if value != nil {
		t.Error("Got wrong value for nil value")
	}
}
