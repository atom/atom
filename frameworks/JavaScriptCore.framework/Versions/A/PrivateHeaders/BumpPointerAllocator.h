/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef BumpPointerAllocator_h
#define BumpPointerAllocator_h

#include <wtf/PageAllocation.h>

namespace WTF {

#define MINIMUM_BUMP_POOL_SIZE 0x1000

class BumpPointerPool {
public:
    // ensureCapacity will check whether the current pool has capacity to
    // allocate 'size' bytes of memory  If it does not, it will attempt to
    // allocate a new pool (which will be added to this one in a chain).
    //
    // If allocation fails (out of memory) this method will return null.
    // If the return value is non-null, then callers should update any
    // references they have to this current (possibly full) BumpPointerPool
    // to instead point to the newly returned BumpPointerPool.
    BumpPointerPool* ensureCapacity(size_t size)
    {
        void* allocationEnd = static_cast<char*>(m_current) + size;
        ASSERT(allocationEnd > m_current); // check for overflow
        if (allocationEnd <= static_cast<void*>(this))
            return this;
        return ensureCapacityCrossPool(this, size);
    }

    // alloc should only be called after calling ensureCapacity; as such
    // alloc will never fail.
    void* alloc(size_t size)
    {
        void* current = m_current;
        void* allocationEnd = static_cast<char*>(current) + size;
        ASSERT(allocationEnd > current); // check for overflow
        ASSERT(allocationEnd <= static_cast<void*>(this));
        m_current = allocationEnd;
        return current;
    }

    // The dealloc method releases memory allocated using alloc.  Memory
    // must be released in a LIFO fashion, e.g. if the client calls alloc
    // four times, returning pointer A, B, C, D, then the only valid order
    // in which these may be deallocaed is D, C, B, A.
    //
    // The client may optionally skip some deallocations.  In the example
    // above, it would be valid to only explicitly dealloc C, A (D being
    // dealloced along with C, B along with A).
    //
    // If pointer was not allocated from this pool (or pools) then dealloc
    // will CRASH().  Callers should update any references they have to
    // this current BumpPointerPool to instead point to the returned
    // BumpPointerPool.
    BumpPointerPool* dealloc(void* position)
    {
        if ((position >= m_start) && (position <= static_cast<void*>(this))) {
            ASSERT(position <= m_current);
            m_current = position;
            return this;
        }
        return deallocCrossPool(this, position);
    }

private:
    // Placement operator new, returns the last 'size' bytes of allocation for use as this.
    void* operator new(size_t size, const PageAllocation& allocation)
    {
        ASSERT(size < allocation.size());
        return reinterpret_cast<char*>(reinterpret_cast<intptr_t>(allocation.base()) + allocation.size()) - size;
    }

    BumpPointerPool(const PageAllocation& allocation)
        : m_current(allocation.base())
        , m_start(allocation.base())
        , m_next(0)
        , m_previous(0)
        , m_allocation(allocation)
    {
    }

    static BumpPointerPool* create(size_t minimumCapacity = 0)
    {
        // Add size of BumpPointerPool object, check for overflow.
        minimumCapacity += sizeof(BumpPointerPool);
        if (minimumCapacity < sizeof(BumpPointerPool))
            return 0;

        size_t poolSize = MINIMUM_BUMP_POOL_SIZE;
        while (poolSize < minimumCapacity) {
            poolSize <<= 1;
            // The following if check relies on MINIMUM_BUMP_POOL_SIZE being a power of 2!
            ASSERT(!(MINIMUM_BUMP_POOL_SIZE & (MINIMUM_BUMP_POOL_SIZE - 1)));
            if (!poolSize)
                return 0;
        }

        PageAllocation allocation = PageAllocation::allocate(poolSize);
        if (!!allocation)
            return new (allocation) BumpPointerPool(allocation);
        return 0;
    }

    void shrink()
    {
        ASSERT(!m_previous);
        m_current = m_start;
        while (m_next) {
            BumpPointerPool* nextNext = m_next->m_next;
            m_next->destroy();
            m_next = nextNext;
        }
    }

    void destroy()
    {
        m_allocation.deallocate();
    }

    static BumpPointerPool* ensureCapacityCrossPool(BumpPointerPool* previousPool, size_t size)
    {
        // The pool passed should not have capacity, so we'll start with the next one.
        ASSERT(previousPool);
        ASSERT((static_cast<char*>(previousPool->m_current) + size) > previousPool->m_current); // check for overflow
        ASSERT((static_cast<char*>(previousPool->m_current) + size) > static_cast<void*>(previousPool));
        BumpPointerPool* pool = previousPool->m_next;

        while (true) {
            if (!pool) {
                // We've run to the end; allocate a new pool.
                pool = BumpPointerPool::create(size);
                previousPool->m_next = pool;
                pool->m_previous = previousPool;
                return pool;
            }

            // 
            void* current = pool->m_current;
            void* allocationEnd = static_cast<char*>(current) + size;
            ASSERT(allocationEnd > current); // check for overflow
            if (allocationEnd <= static_cast<void*>(pool))
                return pool;
        }
    }

    static BumpPointerPool* deallocCrossPool(BumpPointerPool* pool, void* position)
    {
        // Should only be called if position is not in the current pool.
        ASSERT((position < pool->m_start) || (position > static_cast<void*>(pool)));

        while (true) {
            // Unwind the current pool to the start, move back in the chain to the previous pool.
            pool->m_current = pool->m_start;
            pool = pool->m_previous;

            // position was nowhere in the chain!
            if (!pool)
                CRASH();

            if ((position >= pool->m_start) && (position <= static_cast<void*>(pool))) {
                ASSERT(position <= pool->m_current);
                pool->m_current = position;
                return pool;
            }
        }
    }

    void* m_current;
    void* m_start;
    BumpPointerPool* m_next;
    BumpPointerPool* m_previous;
    PageAllocation m_allocation;

    friend class BumpPointerAllocator;
};

// A BumpPointerAllocator manages a set of BumpPointerPool objects, which
// can be used for LIFO (stack like) allocation.
//
// To begin allocating using this class call startAllocator().  The result
// of this method will be null if the initial pool allocation fails, or a
// pointer to a BumpPointerPool object that can be used to perform
// allocations.  Whilst running no memory will be released until
// stopAllocator() is called.  At this point all allocations made through
// this allocator will be reaped, and underlying memory may be freed.
//
// (In practice we will still hold on to the initial pool to allow allocation
// to be quickly restared, but aditional pools will be freed).
//
// This allocator is non-renetrant, it is encumbant on the clients to ensure
// startAllocator() is not called again until stopAllocator() has been called.
class BumpPointerAllocator {
public:
    BumpPointerAllocator()
        : m_head(0)
    {
    }

    ~BumpPointerAllocator()
    {
        if (m_head)
            m_head->destroy();
    }

    BumpPointerPool* startAllocator()
    {
        if (!m_head)
            m_head = BumpPointerPool::create();
        return m_head;
    }

    void stopAllocator()
    {
        if (m_head)
            m_head->shrink();
    }

private:
    BumpPointerPool* m_head;
};

}

using WTF::BumpPointerAllocator;

#endif // BumpPointerAllocator_h
