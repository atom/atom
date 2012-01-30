/*
 * Copyright (C) 2008, 2009 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef StructureTransitionTable_h
#define StructureTransitionTable_h

#include "UString.h"
#include "WeakGCMap.h"
#include <wtf/HashFunctions.h>
#include <wtf/HashTraits.h>
#include <wtf/OwnPtr.h>
#include <wtf/RefPtr.h>

namespace JSC {

class Structure;

class StructureTransitionTable {
    static const intptr_t UsingSingleSlotFlag = 1;

    struct Hash {
        typedef std::pair<RefPtr<StringImpl>, unsigned> Key;
        static unsigned hash(const Key& p)
        {
            return p.first->existingHash();
        }

        static bool equal(const Key& a, const Key& b)
        {
            return a == b;
        }

        static const bool safeToCompareToEmptyOrDeleted = true;
    };

    struct HashTraits {
        typedef WTF::HashTraits<RefPtr<StringImpl> > FirstTraits;
        typedef WTF::GenericHashTraits<unsigned> SecondTraits;
        typedef std::pair<FirstTraits::TraitType, SecondTraits::TraitType > TraitType;

        static const bool emptyValueIsZero = FirstTraits::emptyValueIsZero && SecondTraits::emptyValueIsZero;
        static TraitType emptyValue() { return std::make_pair(FirstTraits::emptyValue(), SecondTraits::emptyValue()); }

        static const bool needsDestruction = FirstTraits::needsDestruction || SecondTraits::needsDestruction;

        static const int minimumTableSize = FirstTraits::minimumTableSize;

        static void constructDeletedValue(TraitType& slot) { FirstTraits::constructDeletedValue(slot.first); }
        static bool isDeletedValue(const TraitType& value) { return FirstTraits::isDeletedValue(value.first); }
    };

    struct WeakGCMapFinalizerCallback {
        static void* finalizerContextFor(Hash::Key)
        {
            return 0;
        }

        static inline Hash::Key keyForFinalizer(void* context, Structure* structure)
        {
            return keyForWeakGCMapFinalizer(context, structure);
        }
    };

    typedef WeakGCMap<Hash::Key, Structure, WeakGCMapFinalizerCallback, Hash, HashTraits> TransitionMap;

    static Hash::Key keyForWeakGCMapFinalizer(void* context, Structure*);

public:
    StructureTransitionTable()
        : m_data(UsingSingleSlotFlag)
    {
    }

    ~StructureTransitionTable()
    {
        if (!isUsingSingleSlot()) {
            delete map();
            return;
        }

        HandleSlot slot = this->slot();
        if (!slot)
            return;
        HandleHeap::heapFor(slot)->deallocate(slot);
    }

    inline void add(JSGlobalData&, Structure*);
    inline bool contains(StringImpl* rep, unsigned attributes) const;
    inline Structure* get(StringImpl* rep, unsigned attributes) const;

private:
    bool isUsingSingleSlot() const
    {
        return m_data & UsingSingleSlotFlag;
    }

    TransitionMap* map() const
    {
        ASSERT(!isUsingSingleSlot());
        return reinterpret_cast<TransitionMap*>(m_data);
    }

    HandleSlot slot() const
    {
        ASSERT(isUsingSingleSlot());
        return reinterpret_cast<HandleSlot>(m_data & ~UsingSingleSlotFlag);
    }

    void setMap(TransitionMap* map)
    {
        ASSERT(isUsingSingleSlot());
        
        if (HandleSlot slot = this->slot())
            HandleHeap::heapFor(slot)->deallocate(slot);

        // This implicitly clears the flag that indicates we're using a single transition
        m_data = reinterpret_cast<intptr_t>(map);

        ASSERT(!isUsingSingleSlot());
    }

    Structure* singleTransition() const
    {
        ASSERT(isUsingSingleSlot());
        if (HandleSlot slot = this->slot()) {
            if (*slot)
                return reinterpret_cast<Structure*>(slot->asCell());
        }
        return 0;
    }
    
    void setSingleTransition(JSGlobalData& globalData, Structure* structure)
    {
        ASSERT(isUsingSingleSlot());
        HandleSlot slot = this->slot();
        if (!slot) {
            slot = globalData.heap.handleHeap()->allocate();
            HandleHeap::heapFor(slot)->makeWeak(slot, 0, 0);
            m_data = reinterpret_cast<intptr_t>(slot) | UsingSingleSlotFlag;
        }
        HandleHeap::heapFor(slot)->writeBarrier(slot, reinterpret_cast<JSCell*>(structure));
        *slot = reinterpret_cast<JSCell*>(structure);
    }

    intptr_t m_data;
};

} // namespace JSC

#endif // StructureTransitionTable_h
