/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2011 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#ifndef MarkedSpace_h
#define MarkedSpace_h

#include "MachineStackMarker.h"
#include "MarkedBlock.h"
#include "PageAllocationAligned.h"
#include <wtf/Bitmap.h>
#include <wtf/DoublyLinkedList.h>
#include <wtf/FixedArray.h>
#include <wtf/HashSet.h>
#include <wtf/Noncopyable.h>
#include <wtf/Vector.h>

#define ASSERT_CLASS_FITS_IN_CELL(class) COMPILE_ASSERT(sizeof(class) <= MarkedSpace::maxCellSize, class_fits_in_cell)

namespace JSC {

class Heap;
class JSCell;
class LiveObjectIterator;
class WeakGCHandle;
class SlotVisitor;

class MarkedSpace {
    WTF_MAKE_NONCOPYABLE(MarkedSpace);
public:
    static const size_t maxCellSize = 2048;

    struct SizeClass {
        SizeClass();
        void resetAllocator();
        void zapFreeList();

        MarkedBlock::FreeCell* firstFreeCell;
        MarkedBlock* currentBlock;
        DoublyLinkedList<HeapBlock> blockList;
        size_t cellSize;
    };

    MarkedSpace(Heap*);

    SizeClass& sizeClassFor(size_t);
    void* allocate(SizeClass&);
    
    void resetAllocator();

    void addBlock(SizeClass&, MarkedBlock*);
    void removeBlock(MarkedBlock*);
    
    void canonicalizeCellLivenessData();

    size_t waterMark();
    size_t nurseryWaterMark();

    template<typename Functor> typename Functor::ReturnType forEachBlock(Functor&); // Safe to remove the current item while iterating.
    template<typename Functor> typename Functor::ReturnType forEachBlock();

private:
    // [ 32... 256 ]
    static const size_t preciseStep = MarkedBlock::atomSize;
    static const size_t preciseCutoff = 256;
    static const size_t preciseCount = preciseCutoff / preciseStep;

    // [ 512... 2048 ]
    static const size_t impreciseStep = preciseCutoff;
    static const size_t impreciseCutoff = maxCellSize;
    static const size_t impreciseCount = impreciseCutoff / impreciseStep;

    FixedArray<SizeClass, preciseCount> m_preciseSizeClasses;
    FixedArray<SizeClass, impreciseCount> m_impreciseSizeClasses;
    size_t m_waterMark;
    size_t m_nurseryWaterMark;
    Heap* m_heap;
};

inline size_t MarkedSpace::waterMark()
{
    return m_waterMark;
}

inline size_t MarkedSpace::nurseryWaterMark()
{
    return m_nurseryWaterMark;
}

inline MarkedSpace::SizeClass& MarkedSpace::sizeClassFor(size_t bytes)
{
    ASSERT(bytes && bytes <= maxCellSize);
    if (bytes <= preciseCutoff)
        return m_preciseSizeClasses[(bytes - 1) / preciseStep];
    return m_impreciseSizeClasses[(bytes - 1) / impreciseStep];
}

inline void* MarkedSpace::allocate(SizeClass& sizeClass)
{
    MarkedBlock::FreeCell* firstFreeCell = sizeClass.firstFreeCell;
    if (!firstFreeCell) {
        for (MarkedBlock*& block = sizeClass.currentBlock; block; block = static_cast<MarkedBlock*>(block->next())) {
            firstFreeCell = block->sweep(MarkedBlock::SweepToFreeList);
            if (firstFreeCell)
                break;
            m_nurseryWaterMark += block->capacity() - block->size();
            m_waterMark += block->capacity();
            block->didConsumeFreeList();
        }

        if (!firstFreeCell)
            return 0;
    }

    ASSERT(firstFreeCell);

    sizeClass.firstFreeCell = firstFreeCell->next;
    return firstFreeCell;
}

template <typename Functor> inline typename Functor::ReturnType MarkedSpace::forEachBlock(Functor& functor)
{
    for (size_t i = 0; i < preciseCount; ++i) {
        SizeClass& sizeClass = m_preciseSizeClasses[i];
        HeapBlock* next;
        for (HeapBlock* block = sizeClass.blockList.head(); block; block = next) {
            next = block->next();
            functor(static_cast<MarkedBlock*>(block));
        }
    }

    for (size_t i = 0; i < impreciseCount; ++i) {
        SizeClass& sizeClass = m_impreciseSizeClasses[i];
        HeapBlock* next;
        for (HeapBlock* block = sizeClass.blockList.head(); block; block = next) {
            next = block->next();
            functor(static_cast<MarkedBlock*>(block));
        }
    }

    return functor.returnValue();
}

template <typename Functor> inline typename Functor::ReturnType MarkedSpace::forEachBlock()
{
    Functor functor;
    return forEachBlock(functor);
}

inline MarkedSpace::SizeClass::SizeClass()
    : firstFreeCell(0)
    , currentBlock(0)
    , cellSize(0)
{
}

inline void MarkedSpace::SizeClass::resetAllocator()
{
    currentBlock = static_cast<MarkedBlock*>(blockList.head());
}

inline void MarkedSpace::SizeClass::zapFreeList()
{
    if (!currentBlock) {
        ASSERT(!firstFreeCell);
        return;
    }

    currentBlock->zapFreeList(firstFreeCell);
    firstFreeCell = 0;
}

} // namespace JSC

#endif // MarkedSpace_h
