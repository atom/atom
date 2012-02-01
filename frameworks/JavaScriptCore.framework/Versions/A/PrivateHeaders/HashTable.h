/*
 * Copyright (C) 2005, 2006, 2007, 2008, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2008 David Levin <levin@chromium.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef WTF_HashTable_h
#define WTF_HashTable_h

#include "Alignment.h"
#include "Assertions.h"
#include "FastMalloc.h"
#include "HashTraits.h"
#include "StdLibExtras.h"
#include "Threading.h"
#include "ValueCheck.h"

namespace WTF {

#define DUMP_HASHTABLE_STATS 0

// Enables internal WTF consistency checks that are invoked automatically. Non-WTF callers can call checkTableConsistency() even if internal checks are disabled.
#define CHECK_HASHTABLE_CONSISTENCY 0

#ifdef NDEBUG
#define CHECK_HASHTABLE_ITERATORS 0
#define CHECK_HASHTABLE_USE_AFTER_DESTRUCTION 0
#else
#define CHECK_HASHTABLE_ITERATORS 1
#define CHECK_HASHTABLE_USE_AFTER_DESTRUCTION 1
#endif

#if DUMP_HASHTABLE_STATS

    struct HashTableStats {
        ~HashTableStats();
        // All of the variables are accessed in ~HashTableStats when the static struct is destroyed.

        // The following variables are all atomically incremented when modified.
        static int numAccesses;
        static int numRehashes;
        static int numRemoves;
        static int numReinserts;

        // The following variables are only modified in the recordCollisionAtCount method within a mutex.
        static int maxCollisions;
        static int numCollisions;
        static int collisionGraph[4096];

        static void recordCollisionAtCount(int count);
    };

#endif

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    class HashTable;
    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    class HashTableIterator;
    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    class HashTableConstIterator;

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void addIterator(const HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>*,
        HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>*);

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void removeIterator(HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>*);

#if !CHECK_HASHTABLE_ITERATORS

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void addIterator(const HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>*,
        HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>*) { }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void removeIterator(HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>*) { }

#endif

    typedef enum { HashItemKnownGood } HashItemKnownGoodTag;

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    class HashTableConstIterator {
    private:
        typedef HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> HashTableType;
        typedef HashTableIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> iterator;
        typedef HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> const_iterator;
        typedef Value ValueType;
        typedef const ValueType& ReferenceType;
        typedef const ValueType* PointerType;

        friend class HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>;
        friend class HashTableIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>;

        void skipEmptyBuckets()
        {
            while (m_position != m_endPosition && HashTableType::isEmptyOrDeletedBucket(*m_position))
                ++m_position;
        }

        HashTableConstIterator(const HashTableType* table, PointerType position, PointerType endPosition)
            : m_position(position), m_endPosition(endPosition)
        {
            addIterator(table, this);
            skipEmptyBuckets();
        }

        HashTableConstIterator(const HashTableType* table, PointerType position, PointerType endPosition, HashItemKnownGoodTag)
            : m_position(position), m_endPosition(endPosition)
        {
            addIterator(table, this);
        }

    public:
        HashTableConstIterator()
        {
            addIterator(static_cast<const HashTableType*>(0), this);
        }

        // default copy, assignment and destructor are OK if CHECK_HASHTABLE_ITERATORS is 0

#if CHECK_HASHTABLE_ITERATORS
        ~HashTableConstIterator()
        {
            removeIterator(this);
        }

        HashTableConstIterator(const const_iterator& other)
            : m_position(other.m_position), m_endPosition(other.m_endPosition)
        {
            addIterator(other.m_table, this);
        }

        const_iterator& operator=(const const_iterator& other)
        {
            m_position = other.m_position;
            m_endPosition = other.m_endPosition;

            removeIterator(this);
            addIterator(other.m_table, this);

            return *this;
        }
#endif

        PointerType get() const
        {
            checkValidity();
            return m_position;
        }
        ReferenceType operator*() const { return *get(); }
        PointerType operator->() const { return get(); }

        const_iterator& operator++()
        {
            checkValidity();
            ASSERT(m_position != m_endPosition);
            ++m_position;
            skipEmptyBuckets();
            return *this;
        }

        // postfix ++ intentionally omitted

        // Comparison.
        bool operator==(const const_iterator& other) const
        {
            checkValidity(other);
            return m_position == other.m_position;
        }
        bool operator!=(const const_iterator& other) const
        {
            checkValidity(other);
            return m_position != other.m_position;
        }
        bool operator==(const iterator& other) const
        {
            return *this == static_cast<const_iterator>(other);
        }
        bool operator!=(const iterator& other) const
        {
            return *this != static_cast<const_iterator>(other);
        }

    private:
        void checkValidity() const
        {
#if CHECK_HASHTABLE_ITERATORS
            ASSERT(m_table);
#endif
        }


#if CHECK_HASHTABLE_ITERATORS
        void checkValidity(const const_iterator& other) const
        {
            ASSERT(m_table);
            ASSERT_UNUSED(other, other.m_table);
            ASSERT(m_table == other.m_table);
        }
#else
        void checkValidity(const const_iterator&) const { }
#endif

        PointerType m_position;
        PointerType m_endPosition;

#if CHECK_HASHTABLE_ITERATORS
    public:
        // Any modifications of the m_next or m_previous of an iterator that is in a linked list of a HashTable::m_iterator,
        // should be guarded with m_table->m_mutex.
        mutable const HashTableType* m_table;
        mutable const_iterator* m_next;
        mutable const_iterator* m_previous;
#endif
    };

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    class HashTableIterator {
    private:
        typedef HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> HashTableType;
        typedef HashTableIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> iterator;
        typedef HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> const_iterator;
        typedef Value ValueType;
        typedef ValueType& ReferenceType;
        typedef ValueType* PointerType;

        friend class HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>;

        HashTableIterator(HashTableType* table, PointerType pos, PointerType end) : m_iterator(table, pos, end) { }
        HashTableIterator(HashTableType* table, PointerType pos, PointerType end, HashItemKnownGoodTag tag) : m_iterator(table, pos, end, tag) { }

    public:
        HashTableIterator() { }

        // default copy, assignment and destructor are OK

        PointerType get() const { return const_cast<PointerType>(m_iterator.get()); }
        ReferenceType operator*() const { return *get(); }
        PointerType operator->() const { return get(); }

        iterator& operator++() { ++m_iterator; return *this; }

        // postfix ++ intentionally omitted

        // Comparison.
        bool operator==(const iterator& other) const { return m_iterator == other.m_iterator; }
        bool operator!=(const iterator& other) const { return m_iterator != other.m_iterator; }
        bool operator==(const const_iterator& other) const { return m_iterator == other; }
        bool operator!=(const const_iterator& other) const { return m_iterator != other; }

        operator const_iterator() const { return m_iterator; }

    private:
        const_iterator m_iterator;
    };

    using std::swap;

    // Work around MSVC's standard library, whose swap for pairs does not swap by component.
    template<typename T> inline void hashTableSwap(T& a, T& b)
    {
        swap(a, b);
    }

    // Swap pairs by component, in case of pair members that specialize swap.
    template<typename T, typename U> inline void hashTableSwap(pair<T, U>& a, pair<T, U>& b)
    {
        swap(a.first, b.first);
        swap(a.second, b.second);
    }

    template<typename T, bool useSwap> struct Mover;
    template<typename T> struct Mover<T, true> { static void move(T& from, T& to) { hashTableSwap(from, to); } };
    template<typename T> struct Mover<T, false> { static void move(T& from, T& to) { to = from; } };

    template<typename HashFunctions> class IdentityHashTranslator {
    public:
        template<typename T> static unsigned hash(const T& key) { return HashFunctions::hash(key); }
        template<typename T> static bool equal(const T& a, const T& b) { return HashFunctions::equal(a, b); }
        template<typename T, typename U> static void translate(T& location, const U&, const T& value) { location = value; }
    };

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    class HashTable {
    public:
        typedef HashTableIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> iterator;
        typedef HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> const_iterator;
        typedef Traits ValueTraits;
        typedef Key KeyType;
        typedef Value ValueType;
        typedef IdentityHashTranslator<HashFunctions> IdentityTranslatorType;

        HashTable();
        ~HashTable() 
        {
            invalidateIterators(); 
            deallocateTable(m_table, m_tableSize); 
#if CHECK_HASHTABLE_USE_AFTER_DESTRUCTION
            m_table = (ValueType*)(uintptr_t)0xbbadbeef;
#endif
        }

        HashTable(const HashTable&);
        void swap(HashTable&);
        HashTable& operator=(const HashTable&);

        iterator begin() { return makeIterator(m_table); }
        iterator end() { return makeKnownGoodIterator(m_table + m_tableSize); }
        const_iterator begin() const { return makeConstIterator(m_table); }
        const_iterator end() const { return makeKnownGoodConstIterator(m_table + m_tableSize); }

        int size() const { return m_keyCount; }
        int capacity() const { return m_tableSize; }
        bool isEmpty() const { return !m_keyCount; }

        pair<iterator, bool> add(const ValueType& value) { return add<IdentityTranslatorType>(Extractor::extract(value), value); }

        // A special version of add() that finds the object by hashing and comparing
        // with some other type, to avoid the cost of type conversion if the object is already
        // in the table.
        template<typename HashTranslator, typename T, typename Extra> pair<iterator, bool> add(const T& key, const Extra&);
        template<typename HashTranslator, typename T, typename Extra> pair<iterator, bool> addPassingHashCode(const T& key, const Extra&);

        iterator find(const KeyType& key) { return find<IdentityTranslatorType>(key); }
        const_iterator find(const KeyType& key) const { return find<IdentityTranslatorType>(key); }
        bool contains(const KeyType& key) const { return contains<IdentityTranslatorType>(key); }

        template<typename HashTranslator, typename T> iterator find(const T&);
        template<typename HashTranslator, typename T> const_iterator find(const T&) const;
        template<typename HashTranslator, typename T> bool contains(const T&) const;

        void remove(const KeyType&);
        void remove(iterator);
        void removeWithoutEntryConsistencyCheck(iterator);
        void removeWithoutEntryConsistencyCheck(const_iterator);
        void clear();

        static bool isEmptyBucket(const ValueType& value) { return Extractor::extract(value) == KeyTraits::emptyValue(); }
        static bool isDeletedBucket(const ValueType& value) { return KeyTraits::isDeletedValue(Extractor::extract(value)); }
        static bool isEmptyOrDeletedBucket(const ValueType& value) { return isEmptyBucket(value) || isDeletedBucket(value); }

        ValueType* lookup(const Key& key) { return lookup<IdentityTranslatorType>(key); }
        template<typename HashTranslator, typename T> ValueType* lookup(const T&);

#if !ASSERT_DISABLED
        void checkTableConsistency() const;
#else
        static void checkTableConsistency() { }
#endif
#if CHECK_HASHTABLE_CONSISTENCY
        void internalCheckTableConsistency() const { checkTableConsistency(); }
        void internalCheckTableConsistencyExceptSize() const { checkTableConsistencyExceptSize(); }
#else
        static void internalCheckTableConsistencyExceptSize() { }
        static void internalCheckTableConsistency() { }
#endif

    private:
        static ValueType* allocateTable(int size);
        static void deallocateTable(ValueType* table, int size);

        typedef pair<ValueType*, bool> LookupType;
        typedef pair<LookupType, unsigned> FullLookupType;

        LookupType lookupForWriting(const Key& key) { return lookupForWriting<IdentityTranslatorType>(key); };
        template<typename HashTranslator, typename T> FullLookupType fullLookupForWriting(const T&);
        template<typename HashTranslator, typename T> LookupType lookupForWriting(const T&);

        template<typename HashTranslator, typename T> void checkKey(const T&);

        void removeAndInvalidateWithoutEntryConsistencyCheck(ValueType*);
        void removeAndInvalidate(ValueType*);
        void remove(ValueType*);

        bool shouldExpand() const { return (m_keyCount + m_deletedCount) * m_maxLoad >= m_tableSize; }
        bool mustRehashInPlace() const { return m_keyCount * m_minLoad < m_tableSize * 2; }
        bool shouldShrink() const { return m_keyCount * m_minLoad < m_tableSize && m_tableSize > KeyTraits::minimumTableSize; }
        void expand();
        void shrink() { rehash(m_tableSize / 2); }

        void rehash(int newTableSize);
        void reinsert(ValueType&);

        static void initializeBucket(ValueType& bucket);
        static void deleteBucket(ValueType& bucket) { bucket.~ValueType(); Traits::constructDeletedValue(bucket); }

        FullLookupType makeLookupResult(ValueType* position, bool found, unsigned hash)
            { return FullLookupType(LookupType(position, found), hash); }

        iterator makeIterator(ValueType* pos) { return iterator(this, pos, m_table + m_tableSize); }
        const_iterator makeConstIterator(ValueType* pos) const { return const_iterator(this, pos, m_table + m_tableSize); }
        iterator makeKnownGoodIterator(ValueType* pos) { return iterator(this, pos, m_table + m_tableSize, HashItemKnownGood); }
        const_iterator makeKnownGoodConstIterator(ValueType* pos) const { return const_iterator(this, pos, m_table + m_tableSize, HashItemKnownGood); }

#if !ASSERT_DISABLED
        void checkTableConsistencyExceptSize() const;
#else
        static void checkTableConsistencyExceptSize() { }
#endif

#if CHECK_HASHTABLE_ITERATORS
        void invalidateIterators();
#else
        static void invalidateIterators() { }
#endif

        static const int m_maxLoad = 2;
        static const int m_minLoad = 6;

        ValueType* m_table;
        int m_tableSize;
        int m_tableSizeMask;
        int m_keyCount;
        int m_deletedCount;

#if CHECK_HASHTABLE_ITERATORS
    public:
        // All access to m_iterators should be guarded with m_mutex.
        mutable const_iterator* m_iterators;
        mutable Mutex m_mutex;
#endif
    };

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::HashTable()
        : m_table(0)
        , m_tableSize(0)
        , m_tableSizeMask(0)
        , m_keyCount(0)
        , m_deletedCount(0)
#if CHECK_HASHTABLE_ITERATORS
        , m_iterators(0)
#endif
    {
    }

    inline unsigned doubleHash(unsigned key)
    {
        key = ~key + (key >> 23);
        key ^= (key << 12);
        key ^= (key >> 7);
        key ^= (key << 2);
        key ^= (key >> 20);
        return key;
    }

#if ASSERT_DISABLED

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template<typename HashTranslator, typename T>
    inline void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::checkKey(const T&)
    {
    }

#else

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template<typename HashTranslator, typename T>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::checkKey(const T& key)
    {
        if (!HashFunctions::safeToCompareToEmptyOrDeleted)
            return;
        ASSERT(!HashTranslator::equal(KeyTraits::emptyValue(), key));
        AlignedBuffer<sizeof(ValueType), WTF_ALIGN_OF(ValueType)> deletedValueBuffer;
        ValueType& deletedValue = *reinterpret_cast_ptr<ValueType*>(deletedValueBuffer.buffer);
        Traits::constructDeletedValue(deletedValue);
        ASSERT(!HashTranslator::equal(Extractor::extract(deletedValue), key));
    }

#endif

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template<typename HashTranslator, typename T>
    inline Value* HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::lookup(const T& key)
    {
        checkKey<HashTranslator>(key);

        int k = 0;
        int sizeMask = m_tableSizeMask;
        ValueType* table = m_table;
        unsigned h = HashTranslator::hash(key);
        int i = h & sizeMask;

        if (!table)
            return 0;

#if DUMP_HASHTABLE_STATS
        atomicIncrement(&HashTableStats::numAccesses);
        int probeCount = 0;
#endif

        while (1) {
            ValueType* entry = table + i;
                
            // we count on the compiler to optimize out this branch
            if (HashFunctions::safeToCompareToEmptyOrDeleted) {
                if (HashTranslator::equal(Extractor::extract(*entry), key))
                    return entry;
                
                if (isEmptyBucket(*entry))
                    return 0;
            } else {
                if (isEmptyBucket(*entry))
                    return 0;
                
                if (!isDeletedBucket(*entry) && HashTranslator::equal(Extractor::extract(*entry), key))
                    return entry;
            }
#if DUMP_HASHTABLE_STATS
            ++probeCount;
            HashTableStats::recordCollisionAtCount(probeCount);
#endif
            if (k == 0)
                k = 1 | doubleHash(h);
            i = (i + k) & sizeMask;
        }
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template<typename HashTranslator, typename T>
    inline typename HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::LookupType HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::lookupForWriting(const T& key)
    {
        ASSERT(m_table);
        checkKey<HashTranslator>(key);

        int k = 0;
        ValueType* table = m_table;
        int sizeMask = m_tableSizeMask;
        unsigned h = HashTranslator::hash(key);
        int i = h & sizeMask;

#if DUMP_HASHTABLE_STATS
        atomicIncrement(&HashTableStats::numAccesses);
        int probeCount = 0;
#endif

        ValueType* deletedEntry = 0;

        while (1) {
            ValueType* entry = table + i;
            
            // we count on the compiler to optimize out this branch
            if (HashFunctions::safeToCompareToEmptyOrDeleted) {
                if (isEmptyBucket(*entry))
                    return LookupType(deletedEntry ? deletedEntry : entry, false);
                
                if (HashTranslator::equal(Extractor::extract(*entry), key))
                    return LookupType(entry, true);
                
                if (isDeletedBucket(*entry))
                    deletedEntry = entry;
            } else {
                if (isEmptyBucket(*entry))
                    return LookupType(deletedEntry ? deletedEntry : entry, false);
            
                if (isDeletedBucket(*entry))
                    deletedEntry = entry;
                else if (HashTranslator::equal(Extractor::extract(*entry), key))
                    return LookupType(entry, true);
            }
#if DUMP_HASHTABLE_STATS
            ++probeCount;
            HashTableStats::recordCollisionAtCount(probeCount);
#endif
            if (k == 0)
                k = 1 | doubleHash(h);
            i = (i + k) & sizeMask;
        }
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template<typename HashTranslator, typename T>
    inline typename HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::FullLookupType HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::fullLookupForWriting(const T& key)
    {
        ASSERT(m_table);
        checkKey<HashTranslator>(key);

        int k = 0;
        ValueType* table = m_table;
        int sizeMask = m_tableSizeMask;
        unsigned h = HashTranslator::hash(key);
        int i = h & sizeMask;

#if DUMP_HASHTABLE_STATS
        atomicIncrement(&HashTableStats::numAccesses);
        int probeCount = 0;
#endif

        ValueType* deletedEntry = 0;

        while (1) {
            ValueType* entry = table + i;
            
            // we count on the compiler to optimize out this branch
            if (HashFunctions::safeToCompareToEmptyOrDeleted) {
                if (isEmptyBucket(*entry))
                    return makeLookupResult(deletedEntry ? deletedEntry : entry, false, h);
                
                if (HashTranslator::equal(Extractor::extract(*entry), key))
                    return makeLookupResult(entry, true, h);
                
                if (isDeletedBucket(*entry))
                    deletedEntry = entry;
            } else {
                if (isEmptyBucket(*entry))
                    return makeLookupResult(deletedEntry ? deletedEntry : entry, false, h);
            
                if (isDeletedBucket(*entry))
                    deletedEntry = entry;
                else if (HashTranslator::equal(Extractor::extract(*entry), key))
                    return makeLookupResult(entry, true, h);
            }
#if DUMP_HASHTABLE_STATS
            ++probeCount;
            HashTableStats::recordCollisionAtCount(probeCount);
#endif
            if (k == 0)
                k = 1 | doubleHash(h);
            i = (i + k) & sizeMask;
        }
    }

    template<bool emptyValueIsZero> struct HashTableBucketInitializer;

    template<> struct HashTableBucketInitializer<false> {
        template<typename Traits, typename Value> static void initialize(Value& bucket)
        {
            new (NotNull, &bucket) Value(Traits::emptyValue());
        }
    };

    template<> struct HashTableBucketInitializer<true> {
        template<typename Traits, typename Value> static void initialize(Value& bucket)
        {
            // This initializes the bucket without copying the empty value.
            // That makes it possible to use this with types that don't support copying.
            // The memset to 0 looks like a slow operation but is optimized by the compilers.
            memset(&bucket, 0, sizeof(bucket));
        }
    };
    
    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::initializeBucket(ValueType& bucket)
    {
        HashTableBucketInitializer<Traits::emptyValueIsZero>::template initialize<Traits>(bucket);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template<typename HashTranslator, typename T, typename Extra>
    inline pair<typename HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::iterator, bool> HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::add(const T& key, const Extra& extra)
    {
        checkKey<HashTranslator>(key);

        invalidateIterators();

        if (!m_table)
            expand();

        internalCheckTableConsistency();

        ASSERT(m_table);

        int k = 0;
        ValueType* table = m_table;
        int sizeMask = m_tableSizeMask;
        unsigned h = HashTranslator::hash(key);
        int i = h & sizeMask;

#if DUMP_HASHTABLE_STATS
        atomicIncrement(&HashTableStats::numAccesses);
        int probeCount = 0;
#endif

        ValueType* deletedEntry = 0;
        ValueType* entry;
        while (1) {
            entry = table + i;
            
            // we count on the compiler to optimize out this branch
            if (HashFunctions::safeToCompareToEmptyOrDeleted) {
                if (isEmptyBucket(*entry))
                    break;
                
                if (HashTranslator::equal(Extractor::extract(*entry), key))
                    return std::make_pair(makeKnownGoodIterator(entry), false);
                
                if (isDeletedBucket(*entry))
                    deletedEntry = entry;
            } else {
                if (isEmptyBucket(*entry))
                    break;
            
                if (isDeletedBucket(*entry))
                    deletedEntry = entry;
                else if (HashTranslator::equal(Extractor::extract(*entry), key))
                    return std::make_pair(makeKnownGoodIterator(entry), false);
            }
#if DUMP_HASHTABLE_STATS
            ++probeCount;
            HashTableStats::recordCollisionAtCount(probeCount);
#endif
            if (k == 0)
                k = 1 | doubleHash(h);
            i = (i + k) & sizeMask;
        }

        if (deletedEntry) {
            initializeBucket(*deletedEntry);
            entry = deletedEntry;
            --m_deletedCount; 
        }

        HashTranslator::translate(*entry, key, extra);

        ++m_keyCount;
        
        if (shouldExpand()) {
            // FIXME: This makes an extra copy on expand. Probably not that bad since
            // expand is rare, but would be better to have a version of expand that can
            // follow a pivot entry and return the new position.
            KeyType enteredKey = Extractor::extract(*entry);
            expand();
            pair<iterator, bool> p = std::make_pair(find(enteredKey), true);
            ASSERT(p.first != end());
            return p;
        }
        
        internalCheckTableConsistency();
        
        return std::make_pair(makeKnownGoodIterator(entry), true);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template<typename HashTranslator, typename T, typename Extra>
    inline pair<typename HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::iterator, bool> HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::addPassingHashCode(const T& key, const Extra& extra)
    {
        checkKey<HashTranslator>(key);

        invalidateIterators();

        if (!m_table)
            expand();

        internalCheckTableConsistency();

        FullLookupType lookupResult = fullLookupForWriting<HashTranslator>(key);

        ValueType* entry = lookupResult.first.first;
        bool found = lookupResult.first.second;
        unsigned h = lookupResult.second;
        
        if (found)
            return std::make_pair(makeKnownGoodIterator(entry), false);
        
        if (isDeletedBucket(*entry)) {
            initializeBucket(*entry);
            --m_deletedCount;
        }
        
        HashTranslator::translate(*entry, key, extra, h);
        ++m_keyCount;
        if (shouldExpand()) {
            // FIXME: This makes an extra copy on expand. Probably not that bad since
            // expand is rare, but would be better to have a version of expand that can
            // follow a pivot entry and return the new position.
            KeyType enteredKey = Extractor::extract(*entry);
            expand();
            pair<iterator, bool> p = std::make_pair(find(enteredKey), true);
            ASSERT(p.first != end());
            return p;
        }

        internalCheckTableConsistency();

        return std::make_pair(makeKnownGoodIterator(entry), true);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::reinsert(ValueType& entry)
    {
        ASSERT(m_table);
        ASSERT(!lookupForWriting(Extractor::extract(entry)).second);
        ASSERT(!isDeletedBucket(*(lookupForWriting(Extractor::extract(entry)).first)));
#if DUMP_HASHTABLE_STATS
        atomicIncrement(&HashTableStats::numReinserts);
#endif

        Mover<ValueType, Traits::needsDestruction>::move(entry, *lookupForWriting(Extractor::extract(entry)).first);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template <typename HashTranslator, typename T> 
    typename HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::iterator HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::find(const T& key)
    {
        if (!m_table)
            return end();

        ValueType* entry = lookup<HashTranslator>(key);
        if (!entry)
            return end();

        return makeKnownGoodIterator(entry);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template <typename HashTranslator, typename T> 
    typename HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::const_iterator HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::find(const T& key) const
    {
        if (!m_table)
            return end();

        ValueType* entry = const_cast<HashTable*>(this)->lookup<HashTranslator>(key);
        if (!entry)
            return end();

        return makeKnownGoodConstIterator(entry);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    template <typename HashTranslator, typename T> 
    bool HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::contains(const T& key) const
    {
        if (!m_table)
            return false;

        return const_cast<HashTable*>(this)->lookup<HashTranslator>(key);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::removeAndInvalidateWithoutEntryConsistencyCheck(ValueType* pos)
    {
        invalidateIterators();
        remove(pos);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::removeAndInvalidate(ValueType* pos)
    {
        invalidateIterators();
        internalCheckTableConsistency();
        remove(pos);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::remove(ValueType* pos)
    {
#if DUMP_HASHTABLE_STATS
        atomicIncrement(&HashTableStats::numRemoves);
#endif

        deleteBucket(*pos);
        ++m_deletedCount;
        --m_keyCount;

        if (shouldShrink())
            shrink();

        internalCheckTableConsistency();
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::remove(iterator it)
    {
        if (it == end())
            return;

        removeAndInvalidate(const_cast<ValueType*>(it.m_iterator.m_position));
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::removeWithoutEntryConsistencyCheck(iterator it)
    {
        if (it == end())
            return;

        removeAndInvalidateWithoutEntryConsistencyCheck(const_cast<ValueType*>(it.m_iterator.m_position));
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::removeWithoutEntryConsistencyCheck(const_iterator it)
    {
        if (it == end())
            return;

        removeAndInvalidateWithoutEntryConsistencyCheck(const_cast<ValueType*>(it.m_position));
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    inline void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::remove(const KeyType& key)
    {
        remove(find(key));
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    Value* HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::allocateTable(int size)
    {
        // would use a template member function with explicit specializations here, but
        // gcc doesn't appear to support that
        if (Traits::emptyValueIsZero)
            return static_cast<ValueType*>(fastZeroedMalloc(size * sizeof(ValueType)));
        ValueType* result = static_cast<ValueType*>(fastMalloc(size * sizeof(ValueType)));
        for (int i = 0; i < size; i++)
            initializeBucket(result[i]);
        return result;
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::deallocateTable(ValueType* table, int size)
    {
        if (Traits::needsDestruction) {
            for (int i = 0; i < size; ++i) {
                if (!isDeletedBucket(table[i]))
                    table[i].~ValueType();
            }
        }
        fastFree(table);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::expand()
    {
        int newSize;
        if (m_tableSize == 0)
            newSize = KeyTraits::minimumTableSize;
        else if (mustRehashInPlace())
            newSize = m_tableSize;
        else
            newSize = m_tableSize * 2;

        rehash(newSize);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::rehash(int newTableSize)
    {
        internalCheckTableConsistencyExceptSize();

        int oldTableSize = m_tableSize;
        ValueType* oldTable = m_table;

#if DUMP_HASHTABLE_STATS
        if (oldTableSize != 0)
            atomicIncrement(&HashTableStats::numRehashes);
#endif

        m_tableSize = newTableSize;
        m_tableSizeMask = newTableSize - 1;
        m_table = allocateTable(newTableSize);

        for (int i = 0; i != oldTableSize; ++i)
            if (!isEmptyOrDeletedBucket(oldTable[i]))
                reinsert(oldTable[i]);

        m_deletedCount = 0;

        deallocateTable(oldTable, oldTableSize);

        internalCheckTableConsistency();
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::clear()
    {
        invalidateIterators();
        deallocateTable(m_table, m_tableSize);
        m_table = 0;
        m_tableSize = 0;
        m_tableSizeMask = 0;
        m_keyCount = 0;
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::HashTable(const HashTable& other)
        : m_table(0)
        , m_tableSize(0)
        , m_tableSizeMask(0)
        , m_keyCount(0)
        , m_deletedCount(0)
#if CHECK_HASHTABLE_ITERATORS
        , m_iterators(0)
#endif
    {
        // Copy the hash table the dumb way, by adding each element to the new table.
        // It might be more efficient to copy the table slots, but it's not clear that efficiency is needed.
        const_iterator end = other.end();
        for (const_iterator it = other.begin(); it != end; ++it)
            add(*it);
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::swap(HashTable& other)
    {
        invalidateIterators();
        other.invalidateIterators();

        ValueType* tmp_table = m_table;
        m_table = other.m_table;
        other.m_table = tmp_table;

        int tmp_tableSize = m_tableSize;
        m_tableSize = other.m_tableSize;
        other.m_tableSize = tmp_tableSize;

        int tmp_tableSizeMask = m_tableSizeMask;
        m_tableSizeMask = other.m_tableSizeMask;
        other.m_tableSizeMask = tmp_tableSizeMask;

        int tmp_keyCount = m_keyCount;
        m_keyCount = other.m_keyCount;
        other.m_keyCount = tmp_keyCount;

        int tmp_deletedCount = m_deletedCount;
        m_deletedCount = other.m_deletedCount;
        other.m_deletedCount = tmp_deletedCount;
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>& HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::operator=(const HashTable& other)
    {
        HashTable tmp(other);
        swap(tmp);
        return *this;
    }

#if !ASSERT_DISABLED

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::checkTableConsistency() const
    {
        checkTableConsistencyExceptSize();
        ASSERT(!m_table || !shouldExpand());
        ASSERT(!shouldShrink());
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::checkTableConsistencyExceptSize() const
    {
        if (!m_table)
            return;

        int count = 0;
        int deletedCount = 0;
        for (int j = 0; j < m_tableSize; ++j) {
            ValueType* entry = m_table + j;
            if (isEmptyBucket(*entry))
                continue;

            if (isDeletedBucket(*entry)) {
                ++deletedCount;
                continue;
            }

            const_iterator it = find(Extractor::extract(*entry));
            ASSERT(entry == it.m_position);
            ++count;

            ValueCheck<Key>::checkConsistency(it->first);
        }

        ASSERT(count == m_keyCount);
        ASSERT(deletedCount == m_deletedCount);
        ASSERT(m_tableSize >= KeyTraits::minimumTableSize);
        ASSERT(m_tableSizeMask);
        ASSERT(m_tableSize == m_tableSizeMask + 1);
    }

#endif // ASSERT_DISABLED

#if CHECK_HASHTABLE_ITERATORS

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>::invalidateIterators()
    {
        MutexLocker lock(m_mutex);
        const_iterator* next;
        for (const_iterator* p = m_iterators; p; p = next) {
            next = p->m_next;
            p->m_table = 0;
            p->m_next = 0;
            p->m_previous = 0;
        }
        m_iterators = 0;
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void addIterator(const HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>* table,
        HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>* it)
    {
        it->m_table = table;
        it->m_previous = 0;

        // Insert iterator at head of doubly-linked list of iterators.
        if (!table) {
            it->m_next = 0;
        } else {
            MutexLocker lock(table->m_mutex);
            ASSERT(table->m_iterators != it);
            it->m_next = table->m_iterators;
            table->m_iterators = it;
            if (it->m_next) {
                ASSERT(!it->m_next->m_previous);
                it->m_next->m_previous = it;
            }
        }
    }

    template<typename Key, typename Value, typename Extractor, typename HashFunctions, typename Traits, typename KeyTraits>
    void removeIterator(HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits>* it)
    {
        typedef HashTable<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> HashTableType;
        typedef HashTableConstIterator<Key, Value, Extractor, HashFunctions, Traits, KeyTraits> const_iterator;

        // Delete iterator from doubly-linked list of iterators.
        if (!it->m_table) {
            ASSERT(!it->m_next);
            ASSERT(!it->m_previous);
        } else {
            MutexLocker lock(it->m_table->m_mutex);
            if (it->m_next) {
                ASSERT(it->m_next->m_previous == it);
                it->m_next->m_previous = it->m_previous;
            }
            if (it->m_previous) {
                ASSERT(it->m_table->m_iterators != it);
                ASSERT(it->m_previous->m_next == it);
                it->m_previous->m_next = it->m_next;
            } else {
                ASSERT(it->m_table->m_iterators == it);
                it->m_table->m_iterators = it->m_next;
            }
        }

        it->m_table = 0;
        it->m_next = 0;
        it->m_previous = 0;
    }

#endif // CHECK_HASHTABLE_ITERATORS

    // iterator adapters

    template<typename HashTableType, typename ValueType> struct HashTableConstIteratorAdapter {
        HashTableConstIteratorAdapter() {}
        HashTableConstIteratorAdapter(const typename HashTableType::const_iterator& impl) : m_impl(impl) {}

        const ValueType* get() const { return (const ValueType*)m_impl.get(); }
        const ValueType& operator*() const { return *get(); }
        const ValueType* operator->() const { return get(); }

        HashTableConstIteratorAdapter& operator++() { ++m_impl; return *this; }
        // postfix ++ intentionally omitted

        typename HashTableType::const_iterator m_impl;
    };

    template<typename HashTableType, typename ValueType> struct HashTableIteratorAdapter {
        HashTableIteratorAdapter() {}
        HashTableIteratorAdapter(const typename HashTableType::iterator& impl) : m_impl(impl) {}

        ValueType* get() const { return (ValueType*)m_impl.get(); }
        ValueType& operator*() const { return *get(); }
        ValueType* operator->() const { return get(); }

        HashTableIteratorAdapter& operator++() { ++m_impl; return *this; }
        // postfix ++ intentionally omitted

        operator HashTableConstIteratorAdapter<HashTableType, ValueType>() {
            typename HashTableType::const_iterator i = m_impl;
            return i;
        }

        typename HashTableType::iterator m_impl;
    };

    template<typename T, typename U>
    inline bool operator==(const HashTableConstIteratorAdapter<T, U>& a, const HashTableConstIteratorAdapter<T, U>& b)
    {
        return a.m_impl == b.m_impl;
    }

    template<typename T, typename U>
    inline bool operator!=(const HashTableConstIteratorAdapter<T, U>& a, const HashTableConstIteratorAdapter<T, U>& b)
    {
        return a.m_impl != b.m_impl;
    }

    template<typename T, typename U>
    inline bool operator==(const HashTableIteratorAdapter<T, U>& a, const HashTableIteratorAdapter<T, U>& b)
    {
        return a.m_impl == b.m_impl;
    }

    template<typename T, typename U>
    inline bool operator!=(const HashTableIteratorAdapter<T, U>& a, const HashTableIteratorAdapter<T, U>& b)
    {
        return a.m_impl != b.m_impl;
    }

    // All 4 combinations of ==, != and Const,non const.
    template<typename T, typename U>
    inline bool operator==(const HashTableConstIteratorAdapter<T, U>& a, const HashTableIteratorAdapter<T, U>& b)
    {
        return a.m_impl == b.m_impl;
    }

    template<typename T, typename U>
    inline bool operator!=(const HashTableConstIteratorAdapter<T, U>& a, const HashTableIteratorAdapter<T, U>& b)
    {
        return a.m_impl != b.m_impl;
    }

    template<typename T, typename U>
    inline bool operator==(const HashTableIteratorAdapter<T, U>& a, const HashTableConstIteratorAdapter<T, U>& b)
    {
        return a.m_impl == b.m_impl;
    }

    template<typename T, typename U>
    inline bool operator!=(const HashTableIteratorAdapter<T, U>& a, const HashTableConstIteratorAdapter<T, U>& b)
    {
        return a.m_impl != b.m_impl;
    }

} // namespace WTF

#include "HashIterators.h"

#endif // WTF_HashTable_h
