/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
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

#ifndef JITCode_h
#define JITCode_h

#if ENABLE(JIT)
#include "CallFrame.h"
#include "JSValue.h"
#include "MacroAssemblerCodeRef.h"
#include "Profiler.h"
#endif

namespace JSC {

#if ENABLE(JIT)
    class JSGlobalData;
    class RegisterFile;
#endif
    
    class JITCode {
#if ENABLE(JIT)
        typedef MacroAssemblerCodeRef CodeRef;
        typedef MacroAssemblerCodePtr CodePtr;
#else
        JITCode() { }
#endif
    public:
        enum JITType { HostCallThunk, BaselineJIT, DFGJIT };
        
        static JITType bottomTierJIT()
        {
            return BaselineJIT;
        }
        
        static JITType topTierJIT()
        {
            return DFGJIT;
        }
        
        static JITType nextTierJIT(JITType jitType)
        {
            ASSERT_UNUSED(jitType, jitType == BaselineJIT || jitType == DFGJIT);
            return DFGJIT;
        }
        
#if ENABLE(JIT)
        JITCode()
        {
        }

        JITCode(const CodeRef ref, JITType jitType)
            : m_ref(ref)
            , m_jitType(jitType)
        {
        }
        
        bool operator !() const
        {
            return !m_ref;
        }

        CodePtr addressForCall()
        {
            return m_ref.code();
        }

        void* executableAddressAtOffset(size_t offset) const
        {
            ASSERT(offset < size());
            return reinterpret_cast<char*>(m_ref.code().executableAddress()) + offset;
        }
        
        void* dataAddressAtOffset(size_t offset) const
        {
            ASSERT(offset < size());
            return reinterpret_cast<char*>(m_ref.code().dataLocation()) + offset;
        }

        // This function returns the offset in bytes of 'pointerIntoCode' into
        // this block of code.  The pointer provided must be a pointer into this
        // block of code.  It is ASSERTed that no codeblock >4gb in size.
        unsigned offsetOf(void* pointerIntoCode)
        {
            intptr_t result = reinterpret_cast<intptr_t>(pointerIntoCode) - reinterpret_cast<intptr_t>(m_ref.code().executableAddress());
            ASSERT(static_cast<intptr_t>(static_cast<unsigned>(result)) == result);
            return static_cast<unsigned>(result);
        }

        // Execute the code!
        inline JSValue execute(RegisterFile* registerFile, CallFrame* callFrame, JSGlobalData* globalData)
        {
            JSValue result = JSValue::decode(ctiTrampoline(m_ref.code().executableAddress(), registerFile, callFrame, 0, Profiler::enabledProfilerReference(), globalData));
            return globalData->exception ? jsNull() : result;
        }

        void* start() const
        {
            return m_ref.code().dataLocation();
        }

        size_t size() const
        {
            ASSERT(m_ref.code().executableAddress());
            return m_ref.size();
        }

        ExecutableMemoryHandle* getExecutableMemory()
        {
            return m_ref.executableMemory();
        }
        
        JITType jitType()
        {
            return m_jitType;
        }

        // Host functions are a bit special; they have a m_code pointer but they
        // do not individully ref the executable pool containing the trampoline.
        static JITCode HostFunction(CodeRef code)
        {
            return JITCode(code, HostCallThunk);
        }

        void clear()
        {
            m_ref.~CodeRef();
            new (NotNull, &m_ref) CodeRef();
        }

    private:
        JITCode(PassRefPtr<ExecutableMemoryHandle> executableMemory, JITType jitType)
            : m_ref(executableMemory)
            , m_jitType(jitType)
        {
        }

        CodeRef m_ref;
        JITType m_jitType;
#endif // ENABLE(JIT)
    };

};

#endif
