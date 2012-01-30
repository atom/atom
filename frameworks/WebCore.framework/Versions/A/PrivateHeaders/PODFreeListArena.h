/*
 * Copyright (C) 2011 Apple Inc.  All rights reserved.
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

#ifndef PODFreeListArena_h
#define PODFreeListArena_h

#include "PODArena.h"

namespace WebCore {

template <class T>
class PODFreeListArena : public PODArena {
public:
    typedef Vector<OwnPtr<Chunk> > ChunkVector;

    static PassRefPtr<PODFreeListArena> create()
    {
        return adoptRef(new PODFreeListArena);
    }

    // Creates a new PODArena configured with the given Allocator.
    static PassRefPtr<PODFreeListArena> create(PassRefPtr<Allocator> allocator)
    {
        return adoptRef(new PODFreeListArena(allocator));
    }

    template<class Argument1Type> T* allocateObject(const Argument1Type& argument1)
    {
        size_t roundedSize = roundUp(sizeof(T), minAlignment<T>());
        void* ptr = allocate(roundedSize);
        if (ptr) {
            // Use placement operator new to allocate a T at this location.
            new(ptr) T(argument1);
        }
        return static_cast<T*>(ptr);
    }

    void freeObject(T* ptr)
    {
        ChunkVector::const_iterator end = m_chunks.end();
        for (ChunkVector::const_iterator it = m_chunks.begin(); it != end; ++it) {
            FreeListChunk* chunk = static_cast<FreeListChunk*>(it->get());
            if (chunk->contains(ptr))
                chunk->free(ptr);
        }
    }

private:
    PODFreeListArena()
        : PODArena() { }

    explicit PODFreeListArena(PassRefPtr<Allocator> allocator)
        : PODArena(allocator) { }

    void* allocate(size_t size)
    {
        void* ptr = 0;
        if (m_current) {
            // First allocate from the current chunk.
            ptr = m_current->allocate(size);
            if (!ptr) {
                // Check if we can allocate from other chunks' free list.
                ChunkVector::const_iterator end = m_chunks.end();
                for (ChunkVector::const_iterator it = m_chunks.begin(); it != end; ++it) {
                    FreeListChunk* chunk = static_cast<FreeListChunk*>(it->get());
                    if (chunk->hasFreeList()) {
                        ptr = chunk->allocate(size);
                        if (ptr)
                            break;
                    }
                }
            }
        }

        if (!ptr) {
            if (size > m_currentChunkSize)
                m_currentChunkSize = size;
            m_chunks.append(adoptPtr(new FreeListChunk(m_allocator.get(), m_currentChunkSize)));
            m_current = m_chunks.last().get();
            ptr = m_current->allocate(size);
        }
        return ptr;
    }

    class FreeListChunk : public PODArena::Chunk {
        WTF_MAKE_NONCOPYABLE(FreeListChunk);

        struct FreeCell {
            FreeCell *m_next;
        };
    public:
        FreeListChunk(Allocator* allocator, size_t size)
            : Chunk(allocator, size)
            , m_freeList(0) { }

        void* allocate(size_t size)
        {
            if (m_freeList) {
                // Reuse a cell from the free list.
                void *cell = m_freeList;
                m_freeList = m_freeList->m_next;
                return cell;
            }

            return Chunk::allocate(size);
        }

        void free(void* ptr)
        {
            // Add the pointer to free list.
            ASSERT(contains(ptr));

            FreeCell* cell = reinterpret_cast<FreeCell*>(ptr);
            cell->m_next = m_freeList;
            m_freeList = cell;
        }

        bool contains(void* ptr) const
        {
            return ptr >= m_base && ptr < m_base + m_size;
        }

        bool hasFreeList() const
        {
            return m_freeList;
        }

    private:
        FreeCell *m_freeList;
    };
};

} // namespace WebCore

#endif
