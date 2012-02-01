/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef WeakGCMap_h
#define WeakGCMap_h

#include "Handle.h"
#include "JSGlobalData.h"
#include <wtf/HashMap.h>

namespace JSC {

// A HashMap for GC'd values that removes entries when the associated value
// dies.
template <typename KeyType, typename MappedType> struct DefaultWeakGCMapFinalizerCallback {
    static void* finalizerContextFor(KeyType key)
    {
        return reinterpret_cast<void*>(key);
    }

    static KeyType keyForFinalizer(void* context, typename HandleTypes<MappedType>::ExternalType)
    {
        return reinterpret_cast<KeyType>(context);
    }
};

template<typename KeyType, typename MappedType, typename FinalizerCallback = DefaultWeakGCMapFinalizerCallback<KeyType, MappedType>, typename HashArg = typename DefaultHash<KeyType>::Hash, typename KeyTraitsArg = HashTraits<KeyType> >
class WeakGCMap : private WeakHandleOwner {
    WTF_MAKE_FAST_ALLOCATED;
    WTF_MAKE_NONCOPYABLE(WeakGCMap);

    typedef HashMap<KeyType, HandleSlot, HashArg, KeyTraitsArg> MapType;
    typedef typename HandleTypes<MappedType>::ExternalType ExternalType;
    typedef typename MapType::iterator map_iterator;

public:

    struct iterator {
        friend class WeakGCMap;
        iterator(map_iterator iter)
            : m_iterator(iter)
        {
        }
        
        std::pair<KeyType, ExternalType> get() const { return std::make_pair(m_iterator->first, HandleTypes<MappedType>::getFromSlot(m_iterator->second)); }
        std::pair<KeyType, HandleSlot> getSlot() const { return *m_iterator; }
        
        iterator& operator++() { ++m_iterator; return *this; }
        
        // postfix ++ intentionally omitted
        
        // Comparison.
        bool operator==(const iterator& other) const { return m_iterator == other.m_iterator; }
        bool operator!=(const iterator& other) const { return m_iterator != other.m_iterator; }
        
    private:
        map_iterator m_iterator;
    };

    WeakGCMap()
    {
    }

    bool isEmpty() { return m_map.isEmpty(); }
    void clear()
    {
        map_iterator end = m_map.end();
        for (map_iterator ptr = m_map.begin(); ptr != end; ++ptr)
            HandleHeap::heapFor(ptr->second)->deallocate(ptr->second);
        m_map.clear();
    }

    bool contains(const KeyType& key) const
    {
        return m_map.contains(key);
    }

    iterator find(const KeyType& key)
    {
        return m_map.find(key);
    }

    void remove(iterator iter)
    {
        ASSERT(iter.m_iterator != m_map.end());
        HandleSlot slot = iter.m_iterator->second;
        ASSERT(slot);
        HandleHeap::heapFor(slot)->deallocate(slot);
        m_map.remove(iter.m_iterator);
    }

    ExternalType get(const KeyType& key) const
    {
        return HandleTypes<MappedType>::getFromSlot(m_map.get(key));
    }

    HandleSlot getSlot(const KeyType& key) const
    {
        return m_map.get(key);
    }

    pair<iterator, bool> add(JSGlobalData& globalData, const KeyType& key, ExternalType value)
    {
        pair<typename MapType::iterator, bool> iter = m_map.add(key, 0);
        if (iter.second) {
            HandleSlot slot = globalData.heap.handleHeap()->allocate();
            iter.first->second = slot;
            HandleHeap::heapFor(slot)->makeWeak(slot, this, FinalizerCallback::finalizerContextFor(key));
            HandleHeap::heapFor(slot)->writeBarrier(slot, value);
            *slot = value;
        }
        return iter;
    }
    
    void set(iterator iter, ExternalType value)
    {
        HandleSlot slot = iter.m_iterator->second;
        ASSERT(slot);
        HandleHeap::heapFor(slot)->writeBarrier(slot, value);
        *slot = value;
    }

    void set(JSGlobalData& globalData, const KeyType& key, ExternalType value)
    {
        pair<typename MapType::iterator, bool> iter = m_map.add(key, 0);
        HandleSlot slot = iter.first->second;
        if (iter.second) {
            slot = globalData.heap.handleHeap()->allocate();
            HandleHeap::heapFor(slot)->makeWeak(slot, this, key);
            iter.first->second = slot;
        }
        HandleHeap::heapFor(slot)->writeBarrier(slot, value);
        *slot = value;
    }

    ExternalType take(const KeyType& key)
    {
        HandleSlot slot = m_map.take(key);
        if (!slot)
            return HashTraits<ExternalType>::emptyValue();
        ExternalType result = HandleTypes<MappedType>::getFromSlot(slot);
        HandleHeap::heapFor(slot)->deallocate(slot);
        return result;
    }

    size_t size() { return m_map.size(); }

    iterator begin() { return iterator(m_map.begin()); }
    iterator end() { return iterator(m_map.end()); }
    
    ~WeakGCMap()
    {
        clear();
    }
    
private:
    virtual void finalize(Handle<Unknown> handle, void* context)
    {
        HandleSlot slot = m_map.take(FinalizerCallback::keyForFinalizer(context, HandleTypes<MappedType>::getFromSlot(handle.slot())));
        ASSERT(slot);
        HandleHeap::heapFor(slot)->deallocate(slot);
    }

    MapType m_map;
};

} // namespace JSC

#endif // WeakGCMap_h
