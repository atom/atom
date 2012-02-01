/*
 * Copyright (C) 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef RegisterFile_h
#define RegisterFile_h

#include "ExecutableAllocator.h"
#include "Register.h"
#include <wtf/Noncopyable.h>
#include <wtf/PageReservation.h>
#include <wtf/VMTags.h>

namespace JSC {

    class ConservativeRoots;
    class DFGCodeBlocks;

    class RegisterFile {
        WTF_MAKE_NONCOPYABLE(RegisterFile);
    public:
        enum CallFrameHeaderEntry {
            CallFrameHeaderSize = 6,

            ArgumentCount = -6,
            CallerFrame = -5,
            Callee = -4,
            ScopeChain = -3,
            ReturnPC = -2, // This is either an Instruction* or a pointer into JIT generated code stored as an Instruction*.
            CodeBlock = -1,
        };

        static const size_t defaultCapacity = 512 * 1024;
        static const size_t commitSize = 16 * 1024;
        // Allow 8k of excess registers before we start trying to reap the registerfile
        static const ptrdiff_t maxExcessCapacity = 8 * 1024;

        RegisterFile(size_t capacity = defaultCapacity);
        ~RegisterFile();
        
        void gatherConservativeRoots(ConservativeRoots&);
        void gatherConservativeRoots(ConservativeRoots&, DFGCodeBlocks&);

        Register* begin() const { return static_cast<Register*>(m_reservation.base()); }
        Register* end() const { return m_end; }
        size_t size() const { return end() - begin(); }

        bool grow(Register*);
        void shrink(Register*);
        
        static size_t committedByteCount();
        static void initializeThreading();

        Register* const * addressOfEnd() const
        {
            return &m_end;
        }

    private:
        bool growSlowCase(Register*);
        void releaseExcessCapacity();
        void addToCommittedByteCount(long);
        Register* m_end;
        Register* m_commitEnd;
        PageReservation m_reservation;
    };

    inline RegisterFile::RegisterFile(size_t capacity)
        : m_end(0)
    {
        ASSERT(capacity && isPageAligned(capacity));

        m_reservation = PageReservation::reserve(roundUpAllocationSize(capacity * sizeof(Register), commitSize), OSAllocator::JSVMStackPages);
        m_end = static_cast<Register*>(m_reservation.base());
        m_commitEnd = static_cast<Register*>(m_reservation.base());
    }

    inline void RegisterFile::shrink(Register* newEnd)
    {
        if (newEnd >= m_end)
            return;
        m_end = newEnd;
        if (m_end == m_reservation.base() && (m_commitEnd - begin()) >= maxExcessCapacity)
            releaseExcessCapacity();
    }

    inline bool RegisterFile::grow(Register* newEnd)
    {
        if (newEnd <= m_end)
            return true;
        return growSlowCase(newEnd);
    }

} // namespace JSC

#endif // RegisterFile_h
