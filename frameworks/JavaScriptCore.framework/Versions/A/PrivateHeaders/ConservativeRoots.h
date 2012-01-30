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

#ifndef ConservativeRoots_h
#define ConservativeRoots_h

#include "Heap.h"
#include <wtf/OSAllocator.h>
#include <wtf/Vector.h>

namespace JSC {

class JSCell;
class DFGCodeBlocks;
class Heap;

class ConservativeRoots {
public:
    ConservativeRoots(const MarkedBlockSet*, BumpSpace*);
    ~ConservativeRoots();

    void add(void* begin, void* end);
    void add(void* begin, void* end, DFGCodeBlocks&);
    
    size_t size();
    JSCell** roots();

private:
    static const size_t inlineCapacity = 128;
    static const size_t nonInlineCapacity = 8192 / sizeof(JSCell*);
    
    template<typename MarkHook>
    void genericAddPointer(void*, TinyBloomFilter, MarkHook&);

    template<typename MarkHook>
    void genericAddSpan(void*, void* end, MarkHook&);
    
    void grow();

    JSCell** m_roots;
    size_t m_size;
    size_t m_capacity;
    const MarkedBlockSet* m_blocks;
    BumpSpace* m_bumpSpace;
    JSCell* m_inlineRoots[inlineCapacity];
};

inline size_t ConservativeRoots::size()
{
    return m_size;
}

inline JSCell** ConservativeRoots::roots()
{
    return m_roots;
}

} // namespace JSC

#endif // ConservativeRoots_h
