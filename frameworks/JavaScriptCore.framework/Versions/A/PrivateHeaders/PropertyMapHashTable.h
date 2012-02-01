/*
 *  Copyright (C) 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 *
 */

#ifndef PropertyMapHashTable_h
#define PropertyMapHashTable_h

#include "UString.h"
#include "WriteBarrier.h"
#include <wtf/HashTable.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/Vector.h>


#ifndef NDEBUG
#define DUMP_PROPERTYMAP_STATS 0
#else
#define DUMP_PROPERTYMAP_STATS 0
#endif

#if DUMP_PROPERTYMAP_STATS

extern int numProbes;
extern int numCollisions;
extern int numRehashes;
extern int numRemoves;

#endif

#define PROPERTY_MAP_DELETED_ENTRY_KEY ((StringImpl*)1) 

namespace JSC {

inline bool isPowerOf2(unsigned v)
{
    // Taken from http://www.cs.utk.edu/~vose/c-stuff/bithacks.html
    
    return !(v & (v - 1)) && v;
}

inline unsigned nextPowerOf2(unsigned v)
{
    // Taken from http://www.cs.utk.edu/~vose/c-stuff/bithacks.html
    // Devised by Sean Anderson, Sepember 14, 2001

    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;

    return v;
}

struct PropertyMapEntry {
    StringImpl* key;
    unsigned offset;
    unsigned attributes;
    WriteBarrier<JSCell> specificValue;

    PropertyMapEntry(JSGlobalData& globalData, JSCell* owner, StringImpl* key, unsigned offset, unsigned attributes, JSCell* specificValue)
        : key(key)
        , offset(offset)
        , attributes(attributes)
        , specificValue(globalData, owner, specificValue, WriteBarrier<JSCell>::MayBeNull)
    {
    }
};

class PropertyTable {
    WTF_MAKE_FAST_ALLOCATED;

    // This is the implementation for 'iterator' and 'const_iterator',
    // used for iterating over the table in insertion order.
    template<typename T>
    class ordered_iterator {
    public:
        ordered_iterator<T>& operator++()
        {
            m_valuePtr = skipDeletedEntries(m_valuePtr + 1);
            return *this;
        }

        bool operator==(const ordered_iterator<T>& other)
        {
            return m_valuePtr == other.m_valuePtr;
        }

        bool operator!=(const ordered_iterator<T>& other)
        {
            return m_valuePtr != other.m_valuePtr;
        }

        T& operator*()
        {
            return *m_valuePtr;
        }

        T* operator->()
        {
            return m_valuePtr;
        }

        ordered_iterator(T* valuePtr)
            : m_valuePtr(valuePtr)
        {
        }

    private:
        T* m_valuePtr;
    };

public:
    typedef StringImpl* KeyType;
    typedef PropertyMapEntry ValueType;

    // The in order iterator provides overloaded * and -> to access the Value at the current position.
    typedef ordered_iterator<ValueType> iterator;
    typedef ordered_iterator<const ValueType> const_iterator;

    // The find_iterator is a pair of a pointer to a Value* an the entry in the index.
    // If 'find' does not find an entry then iter.first will be 0, and iter.second will
    // give the point in m_index where an entry should be inserted.
    typedef std::pair<ValueType*, unsigned> find_iterator;

    // Constructor is passed an initial capacity, a PropertyTable to copy, or both.
    explicit PropertyTable(unsigned initialCapacity);
    PropertyTable(JSGlobalData&, JSCell*, const PropertyTable&);
    PropertyTable(JSGlobalData&, JSCell*, unsigned initialCapacity, const PropertyTable&);
    ~PropertyTable();

    // Ordered iteration methods.
    iterator begin();
    iterator end();
    const_iterator begin() const;
    const_iterator end() const;

    // Find a value in the table.
    find_iterator find(const KeyType&);
    find_iterator findWithString(const KeyType&);
    // Add a value to the table
    std::pair<find_iterator, bool> add(const ValueType& entry);
    // Remove a value from the table.
    void remove(const find_iterator& iter);
    void remove(const KeyType& key);

    // Returns the number of values in the hashtable.
    unsigned size() const;

    // Checks if there are any values in the hashtable.
    bool isEmpty() const;

    // Number of slots in the property storage array in use, included deletedOffsets.
    unsigned propertyStorageSize() const;

    // Used to maintain a list of unused entries in the property storage.
    void clearDeletedOffsets();
    bool hasDeletedOffset();
    unsigned getDeletedOffset();
    void addDeletedOffset(unsigned offset);

    // Copy this PropertyTable, ensuring the copy has at least the capacity provided.
    PassOwnPtr<PropertyTable> copy(JSGlobalData&, JSCell* owner, unsigned newCapacity);

#ifndef NDEBUG
    size_t sizeInMemory();
    void checkConsistency();
#endif

private:
    PropertyTable(const PropertyTable&);
    // Used to insert a value known not to be in the table, and where we know capacity to be available.
    void reinsert(const ValueType& entry);

    // Rehash the table.  Used to grow, or to recover deleted slots.
    void rehash(unsigned newCapacity);

    // The capacity of the table of values is half of the size of the index.
    unsigned tableCapacity() const;

    // We keep an extra deleted slot after the array to make iteration work,
    // and to use for deleted values. Index values into the array are 1-based,
    // so this is tableCapacity() + 1.
    // For example, if m_tableSize is 16, then tableCapacity() is 8 - but the
    // values array is actually 9 long (the 9th used for the deleted value/
    // iteration guard).  The 8 valid entries are numbered 1..8, so the
    // deleted index is 9 (0 being reserved for empty).
    unsigned deletedEntryIndex() const;

    // Used in iterator creation/progression.
    template<typename T>
    static T* skipDeletedEntries(T* valuePtr);

    // The table of values lies after the hash index.
    ValueType* table();
    const ValueType* table() const;

    // total number of  used entries in the values array - by either valid entries, or deleted ones.
    unsigned usedCount() const;

    // The size in bytes of data needed for by the table.
    size_t dataSize();

    // Calculates the appropriate table size (rounds up to a power of two).
    static unsigned sizeForCapacity(unsigned capacity);

    // Check if capacity is available.
    bool canInsert();

    unsigned m_indexSize;
    unsigned m_indexMask;
    unsigned* m_index;
    unsigned m_keyCount;
    unsigned m_deletedCount;
    OwnPtr< Vector<unsigned> > m_deletedOffsets;

    static const unsigned MinimumTableSize = 16;
    static const unsigned EmptyEntryIndex = 0;
};

inline PropertyTable::PropertyTable(unsigned initialCapacity)
    : m_indexSize(sizeForCapacity(initialCapacity))
    , m_indexMask(m_indexSize - 1)
    , m_index(static_cast<unsigned*>(fastZeroedMalloc(dataSize())))
    , m_keyCount(0)
    , m_deletedCount(0)
{
    ASSERT(isPowerOf2(m_indexSize));
}

inline PropertyTable::PropertyTable(JSGlobalData&, JSCell* owner, const PropertyTable& other)
    : m_indexSize(other.m_indexSize)
    , m_indexMask(other.m_indexMask)
    , m_index(static_cast<unsigned*>(fastMalloc(dataSize())))
    , m_keyCount(other.m_keyCount)
    , m_deletedCount(other.m_deletedCount)
{
    ASSERT(isPowerOf2(m_indexSize));

    memcpy(m_index, other.m_index, dataSize());

    iterator end = this->end();
    for (iterator iter = begin(); iter != end; ++iter) {
        iter->key->ref();
        Heap::writeBarrier(owner, iter->specificValue.get());
    }

    // Copy the m_deletedOffsets vector.
    Vector<unsigned>* otherDeletedOffsets = other.m_deletedOffsets.get();
    if (otherDeletedOffsets)
        m_deletedOffsets = adoptPtr(new Vector<unsigned>(*otherDeletedOffsets));
}

inline PropertyTable::PropertyTable(JSGlobalData&, JSCell* owner, unsigned initialCapacity, const PropertyTable& other)
    : m_indexSize(sizeForCapacity(initialCapacity))
    , m_indexMask(m_indexSize - 1)
    , m_index(static_cast<unsigned*>(fastZeroedMalloc(dataSize())))
    , m_keyCount(0)
    , m_deletedCount(0)
{
    ASSERT(isPowerOf2(m_indexSize));
    ASSERT(initialCapacity >= other.m_keyCount);

    const_iterator end = other.end();
    for (const_iterator iter = other.begin(); iter != end; ++iter) {
        ASSERT(canInsert());
        reinsert(*iter);
        iter->key->ref();
        Heap::writeBarrier(owner, iter->specificValue.get());
    }

    // Copy the m_deletedOffsets vector.
    Vector<unsigned>* otherDeletedOffsets = other.m_deletedOffsets.get();
    if (otherDeletedOffsets)
        m_deletedOffsets = adoptPtr(new Vector<unsigned>(*otherDeletedOffsets));
}

inline PropertyTable::~PropertyTable()
{
    iterator end = this->end();
    for (iterator iter = begin(); iter != end; ++iter)
        iter->key->deref();

    fastFree(m_index);
}

inline PropertyTable::iterator PropertyTable::begin()
{
    return iterator(skipDeletedEntries(table()));
}

inline PropertyTable::iterator PropertyTable::end()
{
    return iterator(table() + usedCount());
}

inline PropertyTable::const_iterator PropertyTable::begin() const
{
    return const_iterator(skipDeletedEntries(table()));
}

inline PropertyTable::const_iterator PropertyTable::end() const
{
    return const_iterator(table() + usedCount());
}

inline PropertyTable::find_iterator PropertyTable::find(const KeyType& key)
{
    ASSERT(key);
    ASSERT(key->isIdentifier());
    unsigned hash = key->existingHash();
    unsigned step = 0;

#if DUMP_PROPERTYMAP_STATS
    ++numProbes;
#endif

    while (true) {
        unsigned entryIndex = m_index[hash & m_indexMask];
        if (entryIndex == EmptyEntryIndex)
            return std::make_pair((ValueType*)0, hash & m_indexMask);
        if (key == table()[entryIndex - 1].key)
            return std::make_pair(&table()[entryIndex - 1], hash & m_indexMask);

#if DUMP_PROPERTYMAP_STATS
        ++numCollisions;
#endif

        if (!step)
            step = WTF::doubleHash(key->existingHash()) | 1;
        hash += step;

#if DUMP_PROPERTYMAP_STATS
        ++numRehashes;
#endif
    }
}

inline PropertyTable::find_iterator PropertyTable::findWithString(const KeyType& key)
{
    ASSERT(key);
    ASSERT(!key->isIdentifier() && !key->hasHash());
    unsigned hash = key->hash();
    unsigned step = 0;

#if DUMP_PROPERTYMAP_STATS
    ++numProbes;
#endif

    while (true) {
        unsigned entryIndex = m_index[hash & m_indexMask];
        if (entryIndex == EmptyEntryIndex)
            return std::make_pair((ValueType*)0, hash & m_indexMask);
        if (equal(key, table()[entryIndex - 1].key))
            return std::make_pair(&table()[entryIndex - 1], hash & m_indexMask);

#if DUMP_PROPERTYMAP_STATS
        ++numCollisions;
#endif

        if (!step)
            step = WTF::doubleHash(key->existingHash()) | 1;
        hash += step;

#if DUMP_PROPERTYMAP_STATS
        ++numRehashes;
#endif
    }
}

inline std::pair<PropertyTable::find_iterator, bool> PropertyTable::add(const ValueType& entry)
{
    // Look for a value with a matching key already in the array.
    find_iterator iter = find(entry.key);
    if (iter.first)
        return std::make_pair(iter, false);

    // Ref the key
    entry.key->ref();

    // ensure capacity is available.
    if (!canInsert()) {
        rehash(m_keyCount + 1);
        iter = find(entry.key);
        ASSERT(!iter.first);
    }

    // Allocate a slot in the hashtable, and set the index to reference this.
    unsigned entryIndex = usedCount() + 1;
    m_index[iter.second] = entryIndex;
    iter.first = &table()[entryIndex - 1];
    *iter.first = entry;

    ++m_keyCount;
    return std::make_pair(iter, true);
}

inline void PropertyTable::remove(const find_iterator& iter)
{
    // Removing a key that doesn't exist does nothing!
    if (!iter.first)
        return;

#if DUMP_PROPERTYMAP_STATS
    ++numRemoves;
#endif

    // Replace this one element with the deleted sentinel. Also clear out
    // the entry so we can iterate all the entries as needed.
    m_index[iter.second] = deletedEntryIndex();
    iter.first->key->deref();
    iter.first->key = PROPERTY_MAP_DELETED_ENTRY_KEY;

    ASSERT(m_keyCount >= 1);
    --m_keyCount;
    ++m_deletedCount;

    if (m_deletedCount * 4 >= m_indexSize)
        rehash(m_keyCount);
}

inline void PropertyTable::remove(const KeyType& key)
{
    remove(find(key));
}

// returns the number of values in the hashtable.
inline unsigned PropertyTable::size() const
{
    return m_keyCount;
}

inline bool PropertyTable::isEmpty() const
{
    return !m_keyCount;
}

inline unsigned PropertyTable::propertyStorageSize() const
{
    return size() + (m_deletedOffsets ? m_deletedOffsets->size() : 0);
}

inline void PropertyTable::clearDeletedOffsets()
{
    m_deletedOffsets.clear();
}

inline bool PropertyTable::hasDeletedOffset()
{
    return m_deletedOffsets && !m_deletedOffsets->isEmpty();
}

inline unsigned PropertyTable::getDeletedOffset()
{
    unsigned offset = m_deletedOffsets->last();
    m_deletedOffsets->removeLast();
    return offset;
}

inline void PropertyTable::addDeletedOffset(unsigned offset)
{
    if (!m_deletedOffsets)
        m_deletedOffsets = adoptPtr(new Vector<unsigned>);
    m_deletedOffsets->append(offset);
}

inline PassOwnPtr<PropertyTable> PropertyTable::copy(JSGlobalData& globalData, JSCell* owner, unsigned newCapacity)
{
    ASSERT(newCapacity >= m_keyCount);

    // Fast case; if the new table will be the same m_indexSize as this one, we can memcpy it,
    // save rehashing all keys.
    if (sizeForCapacity(newCapacity) == m_indexSize)
        return adoptPtr(new PropertyTable(globalData, owner, *this));
    return adoptPtr(new PropertyTable(globalData, owner, newCapacity, *this));
}

#ifndef NDEBUG
inline size_t PropertyTable::sizeInMemory()
{
    size_t result = sizeof(PropertyTable) + dataSize();
    if (m_deletedOffsets)
        result += (m_deletedOffsets->capacity() * sizeof(unsigned));
    return result;
}
#endif

inline void PropertyTable::reinsert(const ValueType& entry)
{
    // Used to insert a value known not to be in the table, and where
    // we know capacity to be available.
    ASSERT(canInsert());
    find_iterator iter = find(entry.key);
    ASSERT(!iter.first);

    unsigned entryIndex = usedCount() + 1;
    m_index[iter.second] = entryIndex;
    table()[entryIndex - 1] = entry;

    ++m_keyCount;
}

inline void PropertyTable::rehash(unsigned newCapacity)
{
    unsigned* oldEntryIndices = m_index;
    iterator iter = this->begin();
    iterator end = this->end();

    m_indexSize = sizeForCapacity(newCapacity);
    m_indexMask = m_indexSize - 1;
    m_keyCount = 0;
    m_deletedCount = 0;
    m_index = static_cast<unsigned*>(fastZeroedMalloc(dataSize()));

    for (; iter != end; ++iter) {
        ASSERT(canInsert());
        reinsert(*iter);
    }

    fastFree(oldEntryIndices);
}

inline unsigned PropertyTable::tableCapacity() const { return m_indexSize >> 1; }

inline unsigned PropertyTable::deletedEntryIndex() const { return tableCapacity() + 1; }

template<typename T>
inline T* PropertyTable::skipDeletedEntries(T* valuePtr)
{
    while (valuePtr->key == PROPERTY_MAP_DELETED_ENTRY_KEY)
        ++valuePtr;
    return valuePtr;
}

inline PropertyTable::ValueType* PropertyTable::table()
{
    // The table of values lies after the hash index.
    return reinterpret_cast<ValueType*>(m_index + m_indexSize);
}

inline const PropertyTable::ValueType* PropertyTable::table() const
{
    // The table of values lies after the hash index.
    return reinterpret_cast<const ValueType*>(m_index + m_indexSize);
}

inline unsigned PropertyTable::usedCount() const
{
    // Total number of  used entries in the values array - by either valid entries, or deleted ones.
    return m_keyCount + m_deletedCount;
}

inline size_t PropertyTable::dataSize()
{
    // The size in bytes of data needed for by the table.
    return m_indexSize * sizeof(unsigned) + ((tableCapacity()) + 1) * sizeof(ValueType);
}

inline unsigned PropertyTable::sizeForCapacity(unsigned capacity)
{
    if (capacity < 8)
        return MinimumTableSize;
    return nextPowerOf2(capacity + 1) * 2;
}

inline bool PropertyTable::canInsert()
{
    return usedCount() < tableCapacity();
}

} // namespace JSC

#endif // PropertyMapHashTable_h
