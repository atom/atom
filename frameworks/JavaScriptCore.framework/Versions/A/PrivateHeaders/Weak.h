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

#ifndef Weak_h
#define Weak_h

#include "Assertions.h"
#include "Handle.h"
#include "HandleHeap.h"
#include "JSGlobalData.h"

namespace JSC {

// A weakly referenced handle that becomes 0 when the value it points to is garbage collected.
template <typename T> class Weak : public Handle<T> {
    using Handle<T>::slot;
    using Handle<T>::setSlot;

public:
    typedef typename Handle<T>::ExternalType ExternalType;

    Weak()
        : Handle<T>()
    {
    }

    Weak(JSGlobalData& globalData, ExternalType value = ExternalType(), WeakHandleOwner* weakOwner = 0, void* context = 0)
        : Handle<T>(globalData.heap.handleHeap()->allocate())
    {
        HandleHeap::heapFor(slot())->makeWeak(slot(), weakOwner, context);
        set(value);
    }

    enum AdoptTag { Adopt };
    template<typename U> Weak(AdoptTag, Handle<U> handle)
        : Handle<T>(handle.slot())
    {
        validateCell(get());
    }
    
    Weak(const Weak& other)
        : Handle<T>()
    {
        if (!other.slot())
            return;
        setSlot(HandleHeap::heapFor(other.slot())->copyWeak(other.slot()));
    }

    template <typename U> Weak(const Weak<U>& other)
        : Handle<T>()
    {
        if (!other.slot())
            return;
        setSlot(HandleHeap::heapFor(other.slot())->copyWeak(other.slot()));
    }
    
    enum HashTableDeletedValueTag { HashTableDeletedValue };
    bool isHashTableDeletedValue() const { return slot() == hashTableDeletedValue(); }
    Weak(HashTableDeletedValueTag)
        : Handle<T>(hashTableDeletedValue())
    {
    }

    ~Weak()
    {
        clear();
    }

    void swap(Weak& other)
    {
        Handle<T>::swap(other);
    }

    ExternalType get() const { return  HandleTypes<T>::getFromSlot(slot()); }
    
    void clear()
    {
        if (!slot())
            return;
        HandleHeap::heapFor(slot())->deallocate(slot());
        setSlot(0);
    }
    
    void set(JSGlobalData& globalData, ExternalType value, WeakHandleOwner* weakOwner = 0, void* context = 0)
    {
        if (!slot()) {
            setSlot(globalData.heap.handleHeap()->allocate());
            HandleHeap::heapFor(slot())->makeWeak(slot(), weakOwner, context);
        }
        ASSERT(HandleHeap::heapFor(slot())->hasWeakOwner(slot(), weakOwner));
        set(value);
    }

    template <typename U> Weak& operator=(const Weak<U>& other)
    {
        clear();
        if (other.slot())
            setSlot(HandleHeap::heapFor(other.slot())->copyWeak(other.slot()));
        return *this;
    }

    Weak& operator=(const Weak& other)
    {
        clear();
        if (other.slot())
            setSlot(HandleHeap::heapFor(other.slot())->copyWeak(other.slot()));
        return *this;
    }
    
    HandleSlot leakHandle()
    {
        ASSERT(HandleHeap::heapFor(slot())->hasFinalizer(slot()));
        HandleSlot result = slot();
        setSlot(0);
        return result;
    }

private:
    static HandleSlot hashTableDeletedValue() { return reinterpret_cast<HandleSlot>(-1); }

    void set(ExternalType externalType)
    {
        ASSERT(slot());
        JSValue value = HandleTypes<T>::toJSValue(externalType);
        HandleHeap::heapFor(slot())->writeBarrier(slot(), value);
        *slot() = value;
    }
};

template<class T> inline void swap(Weak<T>& a, Weak<T>& b)
{
    a.swap(b);
}

} // namespace JSC

namespace WTF {

template<typename T> struct VectorTraits<JSC::Weak<T> > : SimpleClassVectorTraits {
    static const bool canCompareWithMemcmp = false;
};

template<typename P> struct HashTraits<JSC::Weak<P> > : SimpleClassHashTraits<JSC::Weak<P> > { };

}

#endif // Weak_h
