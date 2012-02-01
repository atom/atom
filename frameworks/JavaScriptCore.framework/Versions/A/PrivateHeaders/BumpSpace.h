/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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

#ifndef BumpSpace_h
#define BumpSpace_h

#include "TinyBloomFilter.h"
#include <wtf/Assertions.h>
#include <wtf/CheckedBoolean.h>
#include <wtf/DoublyLinkedList.h>
#include <wtf/HashSet.h>
#include <wtf/OSAllocator.h>
#include <wtf/PageAllocationAligned.h>
#include <wtf/StdLibExtras.h>
#include <wtf/ThreadingPrimitives.h>

namespace JSC {

class Heap;
class BumpBlock;
class HeapBlock;

class BumpSpace {
    friend class SlotVisitor;
public:
    BumpSpace(Heap*);
    void init();

    CheckedBoolean tryAllocate(size_t, void**);
    CheckedBoolean tryReallocate(void**, size_t, size_t);
    
    void startedCopying();
    void doneCopying();
    bool isInCopyPhase() { return m_inCopyingPhase; }

    void pin(BumpBlock*);
    bool isPinned(void*);

    bool contains(void*, BumpBlock*&);

    size_t totalMemoryAllocated() { return m_totalMemoryAllocated; }
    size_t totalMemoryUtilized() { return m_totalMemoryUtilized; }

    static BumpBlock* blockFor(void*);

private:
    enum AllocationEffort { AllocationCanFail, AllocationMustSucceed };

    CheckedBoolean tryAllocateSlowCase(size_t, void**);
    CheckedBoolean addNewBlock();
    CheckedBoolean allocateNewBlock(BumpBlock**);
    bool fitsInCurrentBlock(size_t);
    
    static void* allocateFromBlock(BumpBlock*, size_t);
    CheckedBoolean tryAllocateOversize(size_t, void**);
    CheckedBoolean tryReallocateOversize(void**, size_t, size_t);
    
    static bool isOversize(size_t);
    
    CheckedBoolean borrowBlock(BumpBlock**);
    CheckedBoolean getFreshBlock(AllocationEffort, BumpBlock**);
    void doneFillingBlock(BumpBlock*);
    void recycleBlock(BumpBlock*);
    static bool fitsInBlock(BumpBlock*, size_t);
    static BumpBlock* oversizeBlockFor(void* ptr);

    Heap* m_heap;

    BumpBlock* m_currentBlock;

    TinyBloomFilter m_toSpaceFilter;
    TinyBloomFilter m_oversizeFilter;
    HashSet<BumpBlock*> m_toSpaceSet;

    Mutex m_toSpaceLock;
    Mutex m_memoryStatsLock;

    DoublyLinkedList<HeapBlock>* m_toSpace;
    DoublyLinkedList<HeapBlock>* m_fromSpace;
    
    DoublyLinkedList<HeapBlock> m_blocks1;
    DoublyLinkedList<HeapBlock> m_blocks2;
    DoublyLinkedList<HeapBlock> m_oversizeBlocks;
   
    size_t m_totalMemoryAllocated;
    size_t m_totalMemoryUtilized;

    bool m_inCopyingPhase;

    Mutex m_loanedBlocksLock; 
    ThreadCondition m_loanedBlocksCondition;
    size_t m_numberOfLoanedBlocks;

    static const size_t s_blockSize = 64 * KB;
    static const size_t s_maxAllocationSize = 32 * KB;
    static const size_t s_pageSize = 4 * KB;
    static const size_t s_pageMask = ~(s_pageSize - 1);
    static const size_t s_initialBlockNum = 16;
    static const size_t s_blockMask = ~(s_blockSize - 1);
};

} // namespace JSC

#endif
