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

#ifndef WTF_MetaAllocatorHandle_h
#define WTF_MetaAllocatorHandle_h

#include <wtf/Assertions.h>
#include <wtf/RedBlackTree.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace WTF {

class MetaAllocator;

class MetaAllocatorHandle : public RefCounted<MetaAllocatorHandle>, public RedBlackTree<MetaAllocatorHandle, void*>::Node {
private:
    MetaAllocatorHandle(MetaAllocator*, void* start, size_t sizeInBytes);
    
public:
    WTF_EXPORT_PRIVATE ~MetaAllocatorHandle();
    
    void* start()
    {
        return m_start;
    }
    
    void* end()
    {
        return reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(m_start) + m_sizeInBytes);
    }
        
    size_t sizeInBytes()
    {
        return m_sizeInBytes;
    }
        
    WTF_EXPORT_PRIVATE void shrink(size_t newSizeInBytes);
    
    bool isManaged()
    {
        return !!m_allocator;
    }
        
    MetaAllocator* allocator()
    {
        ASSERT(m_allocator);
        return m_allocator;
    }
    
    void* key()
    {
        return m_start;
    }
    
private:
    friend class MetaAllocator;
    
    MetaAllocator* m_allocator;
    void* m_start;
    size_t m_sizeInBytes;
};

}

#endif
