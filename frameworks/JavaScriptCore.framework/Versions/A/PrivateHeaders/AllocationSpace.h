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

#ifndef AllocationSpace_h
#define AllocationSpace_h

#include "MarkedBlockSet.h"
#include "MarkedSpace.h"

#include <wtf/HashSet.h>

namespace JSC {

class Heap;
class MarkedBlock;

class AllocationSpace {
public:
    AllocationSpace(Heap* heap)
        : m_heap(heap)
        , m_markedSpace(heap)
    {
    }
    
    typedef HashSet<MarkedBlock*>::iterator BlockIterator;
    
    MarkedBlockSet& blocks() { return m_blocks; }
    MarkedSpace::SizeClass& sizeClassFor(size_t bytes) { return m_markedSpace.sizeClassFor(bytes); }
    size_t waterMark() { return m_markedSpace.waterMark(); }

#if ENABLE(GGC)
    void gatherDirtyCells(MarkedBlock::DirtyCellVector&);
#endif

    template<typename Functor> typename Functor::ReturnType forEachCell(Functor&);
    template<typename Functor> typename Functor::ReturnType forEachCell();
    template<typename Functor> typename Functor::ReturnType forEachBlock(Functor&);
    template<typename Functor> typename Functor::ReturnType forEachBlock();
    
    void canonicalizeCellLivenessData() { m_markedSpace.canonicalizeCellLivenessData(); }
    void resetAllocator() { m_markedSpace.resetAllocator(); }
    
    void* allocate(size_t);
    void freeBlocks(MarkedBlock*);
    void shrink();
    
private:
    enum AllocationEffort { AllocationCanFail, AllocationMustSucceed };

    void* allocate(MarkedSpace::SizeClass&);
    void* tryAllocate(MarkedSpace::SizeClass&);
    JS_EXPORT_PRIVATE void* allocateSlowCase(MarkedSpace::SizeClass&);
    MarkedBlock* allocateBlock(size_t cellSize, AllocationEffort);
    
    Heap* m_heap;
    MarkedSpace m_markedSpace;
    MarkedBlockSet m_blocks;
};

template<typename Functor> inline typename Functor::ReturnType AllocationSpace::forEachCell(Functor& functor)
{
    canonicalizeCellLivenessData();

    BlockIterator end = m_blocks.set().end();
    for (BlockIterator it = m_blocks.set().begin(); it != end; ++it)
        (*it)->forEachCell(functor);
    return functor.returnValue();
}

template<typename Functor> inline typename Functor::ReturnType AllocationSpace::forEachCell()
{
    Functor functor;
    return forEachCell(functor);
}

template<typename Functor> inline typename Functor::ReturnType AllocationSpace::forEachBlock(Functor& functor)
{
    BlockIterator end = m_blocks.set().end();
    for (BlockIterator it = m_blocks.set().begin(); it != end; ++it)
        functor(*it);
    return functor.returnValue();
}

template<typename Functor> inline typename Functor::ReturnType AllocationSpace::forEachBlock()
{
    Functor functor;
    return forEachBlock(functor);
}

inline void* AllocationSpace::allocate(MarkedSpace::SizeClass& sizeClass)
{
    // This is a light-weight fast path to cover the most common case.
    MarkedBlock::FreeCell* firstFreeCell = sizeClass.firstFreeCell;
    if (UNLIKELY(!firstFreeCell))
        return allocateSlowCase(sizeClass);
    
    sizeClass.firstFreeCell = firstFreeCell->next;
    return firstFreeCell;
}

inline void* AllocationSpace::allocate(size_t bytes)
{
    MarkedSpace::SizeClass& sizeClass = sizeClassFor(bytes);
    return allocate(sizeClass);
}

}

#endif
