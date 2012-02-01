/*
 * Copyright (C) 2005, 2006, 2007, 2008, 2011 Apple Inc. All rights reserved.
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

#ifndef WTF_HashSet_h
#define WTF_HashSet_h

#include "FastAllocBase.h"
#include "HashTable.h"

namespace WTF {

    struct IdentityExtractor;
    
    template<typename Value, typename HashFunctions, typename Traits> class HashSet;
    template<typename Value, typename HashFunctions, typename Traits>
    void deleteAllValues(const HashSet<Value, HashFunctions, Traits>&);
    template<typename Value, typename HashFunctions, typename Traits>
    void fastDeleteAllValues(const HashSet<Value, HashFunctions, Traits>&);

    template<typename ValueArg, typename HashArg = typename DefaultHash<ValueArg>::Hash,
        typename TraitsArg = HashTraits<ValueArg> > class HashSet {
        WTF_MAKE_FAST_ALLOCATED;
    private:
        typedef HashArg HashFunctions;
        typedef TraitsArg ValueTraits;

    public:
        typedef typename ValueTraits::TraitType ValueType;

    private:
        typedef HashTable<ValueType, ValueType, IdentityExtractor,
            HashFunctions, ValueTraits, ValueTraits> HashTableType;

    public:
        typedef HashTableConstIteratorAdapter<HashTableType, ValueType> iterator;
        typedef HashTableConstIteratorAdapter<HashTableType, ValueType> const_iterator;

        void swap(HashSet&);

        int size() const;
        int capacity() const;
        bool isEmpty() const;

        iterator begin() const;
        iterator end() const;

        iterator find(const ValueType&) const;
        bool contains(const ValueType&) const;

        // An alternate version of find() that finds the object by hashing and comparing
        // with some other type, to avoid the cost of type conversion. HashTranslator
        // must have the following function members:
        //   static unsigned hash(const T&);
        //   static bool equal(const ValueType&, const T&);
        // FIXME: We should reverse the order of the template arguments so that callers
        // can just pass the translator and let the compiler deduce T.
        template<typename T, typename HashTranslator> iterator find(const T&) const;
        template<typename T, typename HashTranslator> bool contains(const T&) const;

        // The return value is a pair of an interator to the new value's location, 
        // and a bool that is true if an new entry was added.
        pair<iterator, bool> add(const ValueType&);

        // An alternate version of add() that finds the object by hashing and comparing
        // with some other type, to avoid the cost of type conversion if the object is already
        // in the table. HashTranslator must have the following function members:
        //   static unsigned hash(const T&);
        //   static bool equal(const ValueType&, const T&);
        //   static translate(ValueType&, const T&, unsigned hashCode);
        // FIXME: We should reverse the order of the template arguments so that callers
        // can just pass the translator and let the compiler deduce T.
        template<typename T, typename HashTranslator> pair<iterator, bool> add(const T&);

        void remove(const ValueType&);
        void remove(iterator);
        void clear();

    private:
        friend void deleteAllValues<>(const HashSet&);
        friend void fastDeleteAllValues<>(const HashSet&);

        HashTableType m_impl;
    };

    struct IdentityExtractor {
        template<typename T> static const T& extract(const T& t) { return t; }
    };

    template<typename Translator>
    struct HashSetTranslatorAdapter {
        template<typename T> static unsigned hash(const T& key) { return Translator::hash(key); }
        template<typename T, typename U> static bool equal(const T& a, const U& b) { return Translator::equal(a, b); }
        template<typename T, typename U> static void translate(T& location, const U& key, const U&, unsigned hashCode)
        {
            Translator::translate(location, key, hashCode);
        }
    };

    template<typename T, typename U, typename V>
    inline void HashSet<T, U, V>::swap(HashSet& other)
    {
        m_impl.swap(other.m_impl); 
    }

    template<typename T, typename U, typename V>
    inline int HashSet<T, U, V>::size() const
    {
        return m_impl.size(); 
    }

    template<typename T, typename U, typename V>
    inline int HashSet<T, U, V>::capacity() const
    {
        return m_impl.capacity(); 
    }

    template<typename T, typename U, typename V>
    inline bool HashSet<T, U, V>::isEmpty() const
    {
        return m_impl.isEmpty(); 
    }

    template<typename T, typename U, typename V>
    inline typename HashSet<T, U, V>::iterator HashSet<T, U, V>::begin() const
    {
        return m_impl.begin(); 
    }

    template<typename T, typename U, typename V>
    inline typename HashSet<T, U, V>::iterator HashSet<T, U, V>::end() const
    {
        return m_impl.end(); 
    }

    template<typename T, typename U, typename V>
    inline typename HashSet<T, U, V>::iterator HashSet<T, U, V>::find(const ValueType& value) const
    {
        return m_impl.find(value); 
    }

    template<typename T, typename U, typename V>
    inline bool HashSet<T, U, V>::contains(const ValueType& value) const
    {
        return m_impl.contains(value); 
    }

    template<typename Value, typename HashFunctions, typename Traits>
    template<typename T, typename HashTranslator>
    typename HashSet<Value, HashFunctions, Traits>::iterator
    inline HashSet<Value, HashFunctions, Traits>::find(const T& value) const
    {
        return m_impl.template find<HashSetTranslatorAdapter<HashTranslator> >(value);
    }

    template<typename Value, typename HashFunctions, typename Traits>
    template<typename T, typename HashTranslator>
    inline bool HashSet<Value, HashFunctions, Traits>::contains(const T& value) const
    {
        return m_impl.template contains<HashSetTranslatorAdapter<HashTranslator> >(value);
    }

    template<typename T, typename U, typename V>
    inline pair<typename HashSet<T, U, V>::iterator, bool> HashSet<T, U, V>::add(const ValueType& value)
    {
        return m_impl.add(value);
    }

    template<typename Value, typename HashFunctions, typename Traits>
    template<typename T, typename HashTranslator>
    inline pair<typename HashSet<Value, HashFunctions, Traits>::iterator, bool>
    HashSet<Value, HashFunctions, Traits>::add(const T& value)
    {
        return m_impl.template addPassingHashCode<HashSetTranslatorAdapter<HashTranslator> >(value, value);
    }

    template<typename T, typename U, typename V>
    inline void HashSet<T, U, V>::remove(iterator it)
    {
        if (it.m_impl == m_impl.end())
            return;
        m_impl.internalCheckTableConsistency();
        m_impl.removeWithoutEntryConsistencyCheck(it.m_impl);
    }

    template<typename T, typename U, typename V>
    inline void HashSet<T, U, V>::remove(const ValueType& value)
    {
        remove(find(value));
    }

    template<typename T, typename U, typename V>
    inline void HashSet<T, U, V>::clear()
    {
        m_impl.clear(); 
    }

    template<typename ValueType, typename HashTableType>
    void deleteAllValues(HashTableType& collection)
    {
        typedef typename HashTableType::const_iterator iterator;
        iterator end = collection.end();
        for (iterator it = collection.begin(); it != end; ++it)
            delete *it;
    }

    template<typename T, typename U, typename V>
    inline void deleteAllValues(const HashSet<T, U, V>& collection)
    {
        deleteAllValues<typename HashSet<T, U, V>::ValueType>(collection.m_impl);
    }

    template<typename ValueType, typename HashTableType>
    void fastDeleteAllValues(HashTableType& collection)
    {
        typedef typename HashTableType::const_iterator iterator;
        iterator end = collection.end();
        for (iterator it = collection.begin(); it != end; ++it)
            fastDelete(*it);
    }

    template<typename T, typename U, typename V>
    inline void fastDeleteAllValues(const HashSet<T, U, V>& collection)
    {
        fastDeleteAllValues<typename HashSet<T, U, V>::ValueType>(collection.m_impl);
    }
    
    template<typename T, typename U, typename V, typename W>
    inline void copyToVector(const HashSet<T, U, V>& collection, W& vector)
    {
        typedef typename HashSet<T, U, V>::const_iterator iterator;
        
        vector.resize(collection.size());
        
        iterator it = collection.begin();
        iterator end = collection.end();
        for (unsigned i = 0; it != end; ++it, ++i)
            vector[i] = *it;
    }  

} // namespace WTF

using WTF::HashSet;

#endif /* WTF_HashSet_h */
