/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef WTF_MetaAllocator_h
#define WTF_MetaAllocator_h

#include "Assertions.h"
#include "HashMap.h"
#include "MetaAllocatorHandle.h"
#include "Noncopyable.h"
#include "PageBlock.h"
#include "RedBlackTree.h"
#include "RefCounted.h"
#include "RefPtr.h"
#include "TCSpinLock.h"

namespace WTF {

#define ENABLE_META_ALLOCATOR_PROFILE 0

class MetaAllocatorTracker {
public:
    void notify(MetaAllocatorHandle*);
    void release(MetaAllocatorHandle*);

    MetaAllocatorHandle* find(void* address)
    {
        MetaAllocatorHandle* handle = m_allocations.findGreatestLessThanOrEqual(address);
        if (handle && address < handle->end())
            return handle;
        return 0;
    }

    RedBlackTree<MetaAllocatorHandle, void*> m_allocations;
};

class MetaAllocator {
    WTF_MAKE_NONCOPYABLE(MetaAllocator);

public:
    WTF_EXPORT_PRIVATE MetaAllocator(size_t allocationGranule);
    
    virtual ~MetaAllocator();
    
    WTF_EXPORT_PRIVATE PassRefPtr<MetaAllocatorHandle> allocate(size_t sizeInBytes);

    void trackAllocations(MetaAllocatorTracker* tracker)
    {
        m_tracker = tracker;
    }
    
    // Non-atomic methods for getting allocator statistics.
    size_t bytesAllocated() { return m_bytesAllocated; }
    size_t bytesReserved() { return m_bytesReserved; }
    size_t bytesCommitted() { return m_bytesCommitted; }
    
    // Atomic method for getting allocator statistics.
    struct Statistics {
        size_t bytesAllocated;
        size_t bytesReserved;
        size_t bytesCommitted;
    };
    Statistics currentStatistics();

    // Add more free space to the allocator. Call this directly from
    // the constructor if you wish to operate the allocator within a
    // fixed pool.
    WTF_EXPORT_PRIVATE void addFreshFreeSpace(void* start, size_t sizeInBytes);

    // This is meant only for implementing tests. Never call this in release
    // builds.
    WTF_EXPORT_PRIVATE size_t debugFreeSpaceSize();
    
#if ENABLE(META_ALLOCATOR_PROFILE)
    void dumpProfile();
#else
    void dumpProfile() { }
#endif

protected:
    
    // Allocate new virtual space, but don't commit. This may return more
    // pages than we asked, in which case numPages is changed.
    virtual void* allocateNewSpace(size_t& numPages) = 0;
    
    // Commit a page.
    virtual void notifyNeedPage(void* page) = 0;
    
    // Uncommit a page.
    virtual void notifyPageIsFree(void* page) = 0;
    
    // NOTE: none of the above methods are called during allocator
    // destruction, in part because a MetaAllocator cannot die so long
    // as there are Handles that refer to it.

private:
    
    friend class MetaAllocatorHandle;
    
    class FreeSpaceNode : public RedBlackTree<FreeSpaceNode, size_t>::Node {
    public:
        FreeSpaceNode(void* start, size_t sizeInBytes)
            : m_start(start)
            , m_sizeInBytes(sizeInBytes)
        {
        }

        size_t key()
        {
            return m_sizeInBytes;
        }

        void* m_start;
        size_t m_sizeInBytes;
    };
    typedef RedBlackTree<FreeSpaceNode, size_t> Tree;

    // Release a MetaAllocatorHandle.
    void release(MetaAllocatorHandle*);
    
    // Remove free space from the allocator. This is effectively
    // the allocate() function, except that it does not mark the
    // returned space as being in-use.
    void* findAndRemoveFreeSpace(size_t sizeInBytes);

    // This is called when memory from an allocation is freed.
    void addFreeSpaceFromReleasedHandle(void* start, size_t sizeInBytes);
    
    // This is the low-level implementation of adding free space; it
    // is called from both addFreeSpaceFromReleasedHandle and from
    // addFreshFreeSpace.
    void addFreeSpace(void* start, size_t sizeInBytes);
    
    // Management of used space.
    
    void incrementPageOccupancy(void* address, size_t sizeInBytes);
    void decrementPageOccupancy(void* address, size_t sizeInBytes);

    // Utilities.
    
    size_t roundUp(size_t sizeInBytes);
    
    FreeSpaceNode* allocFreeSpaceNode();
    WTF_EXPORT_PRIVATE void freeFreeSpaceNode(FreeSpaceNode*);
    
    size_t m_allocationGranule;
    unsigned m_logAllocationGranule;
    size_t m_pageSize;
    unsigned m_logPageSize;
    
    Tree m_freeSpaceSizeMap;
    HashMap<void*, FreeSpaceNode*> m_freeSpaceStartAddressMap;
    HashMap<void*, FreeSpaceNode*> m_freeSpaceEndAddressMap;
    HashMap<uintptr_t, size_t> m_pageOccupancyMap;
    
    size_t m_bytesAllocated;
    size_t m_bytesReserved;
    size_t m_bytesCommitted;
    
    SpinLock m_lock;

    MetaAllocatorTracker* m_tracker;

#ifndef NDEBUG
    size_t m_mallocBalance;
#endif

#if ENABLE(META_ALLOCATOR_PROFILE)
    unsigned m_numAllocations;
    unsigned m_numFrees;
#endif
};

inline MetaAllocator::~MetaAllocator()
{
    for (FreeSpaceNode* node = m_freeSpaceSizeMap.first(); node;) {
        FreeSpaceNode* next = node->successor();
        m_freeSpaceSizeMap.remove(node);
        freeFreeSpaceNode(node);
        node = next;
    }
#ifndef NDEBUG
    ASSERT(!m_mallocBalance);
#endif
}

} // namespace WTF

#endif // WTF_MetaAllocator_h

