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

#ifndef MacroAssemblerCodeRef_h
#define MacroAssemblerCodeRef_h

#include "ExecutableAllocator.h"
#include "PassRefPtr.h"
#include "RefPtr.h"
#include "UnusedParam.h"

#if ENABLE(ASSEMBLER)

// ASSERT_VALID_CODE_POINTER checks that ptr is a non-null pointer, and that it is a valid
// instruction address on the platform (for example, check any alignment requirements).
#if CPU(ARM_THUMB2)
// ARM/thumb instructions must be 16-bit aligned, but all code pointers to be loaded
// into the processor are decorated with the bottom bit set, indicating that this is
// thumb code (as oposed to 32-bit traditional ARM).  The first test checks for both
// decorated and undectorated null, and the second test ensures that the pointer is
// decorated.
#define ASSERT_VALID_CODE_POINTER(ptr) \
    ASSERT(reinterpret_cast<intptr_t>(ptr) & ~1); \
    ASSERT(reinterpret_cast<intptr_t>(ptr) & 1)
#define ASSERT_VALID_CODE_OFFSET(offset) \
    ASSERT(!(offset & 1)) // Must be multiple of 2.
#else
#define ASSERT_VALID_CODE_POINTER(ptr) \
    ASSERT(ptr)
#define ASSERT_VALID_CODE_OFFSET(offset) // Anything goes!
#endif

#if CPU(X86) && OS(WIN)
#define CALLING_CONVENTION_IS_STDCALL 1
#ifndef CDECL
#if COMPILER(MSVC)
#define CDECL __cdecl
#else
#define CDECL __attribute__ ((__cdecl))
#endif // COMPILER(MSVC)
#endif // CDECL
#else
#define CALLING_CONVENTION_IS_STDCALL 0
#endif

#if CPU(X86)
#define HAS_FASTCALL_CALLING_CONVENTION 1
#ifndef FASTCALL
#if COMPILER(MSVC)
#define FASTCALL __fastcall
#else
#define FASTCALL  __attribute__ ((fastcall))
#endif // COMPILER(MSVC)
#endif // FASTCALL
#else
#define HAS_FASTCALL_CALLING_CONVENTION 0
#endif // CPU(X86)

namespace JSC {

// FunctionPtr:
//
// FunctionPtr should be used to wrap pointers to C/C++ functions in JSC
// (particularly, the stub functions).
class FunctionPtr {
public:
    FunctionPtr()
        : m_value(0)
    {
    }

    template<typename returnType>
    FunctionPtr(returnType(*value)())
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1>
    FunctionPtr(returnType(*value)(argType1))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2>
    FunctionPtr(returnType(*value)(argType1, argType2))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2, typename argType3>
    FunctionPtr(returnType(*value)(argType1, argType2, argType3))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2, typename argType3, typename argType4>
    FunctionPtr(returnType(*value)(argType1, argType2, argType3, argType4))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

#if CALLING_CONVENTION_IS_STDCALL

    template<typename returnType>
    FunctionPtr(returnType (CDECL *value)())
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1>
    FunctionPtr(returnType (CDECL *value)(argType1))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2>
    FunctionPtr(returnType (CDECL *value)(argType1, argType2))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2, typename argType3>
    FunctionPtr(returnType (CDECL *value)(argType1, argType2, argType3))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2, typename argType3, typename argType4>
    FunctionPtr(returnType (CDECL *value)(argType1, argType2, argType3, argType4))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }
#endif

#if HAS_FASTCALL_CALLING_CONVENTION

    template<typename returnType>
    FunctionPtr(returnType (FASTCALL *value)())
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1>
    FunctionPtr(returnType (FASTCALL *value)(argType1))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2>
    FunctionPtr(returnType (FASTCALL *value)(argType1, argType2))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2, typename argType3>
    FunctionPtr(returnType (FASTCALL *value)(argType1, argType2, argType3))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    template<typename returnType, typename argType1, typename argType2, typename argType3, typename argType4>
    FunctionPtr(returnType (FASTCALL *value)(argType1, argType2, argType3, argType4))
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }
#endif

    template<typename FunctionType>
    explicit FunctionPtr(FunctionType* value)
        // Using a C-ctyle cast here to avoid compiler error on RVTC:
        // Error:  #694: reinterpret_cast cannot cast away const or other type qualifiers
        // (I guess on RVTC function pointers have a different constness to GCC/MSVC?)
        : m_value((void*)value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    void* value() const { return m_value; }
    void* executableAddress() const { return m_value; }


private:
    void* m_value;
};

// ReturnAddressPtr:
//
// ReturnAddressPtr should be used to wrap return addresses generated by processor
// 'call' instructions exectued in JIT code.  We use return addresses to look up
// exception and optimization information, and to repatch the call instruction
// that is the source of the return address.
class ReturnAddressPtr {
public:
    ReturnAddressPtr()
        : m_value(0)
    {
    }

    explicit ReturnAddressPtr(void* value)
        : m_value(value)
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    explicit ReturnAddressPtr(FunctionPtr function)
        : m_value(function.value())
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    void* value() const { return m_value; }

private:
    void* m_value;
};

// MacroAssemblerCodePtr:
//
// MacroAssemblerCodePtr should be used to wrap pointers to JIT generated code.
class MacroAssemblerCodePtr {
public:
    MacroAssemblerCodePtr()
        : m_value(0)
    {
    }

    explicit MacroAssemblerCodePtr(void* value)
#if CPU(ARM_THUMB2)
        // Decorate the pointer as a thumb code pointer.
        : m_value(reinterpret_cast<char*>(value) + 1)
#else
        : m_value(value)
#endif
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    explicit MacroAssemblerCodePtr(ReturnAddressPtr ra)
        : m_value(ra.value())
    {
        ASSERT_VALID_CODE_POINTER(m_value);
    }

    void* executableAddress() const { return m_value; }
#if CPU(ARM_THUMB2)
    // To use this pointer as a data address remove the decoration.
    void* dataLocation() const { ASSERT_VALID_CODE_POINTER(m_value); return reinterpret_cast<char*>(m_value) - 1; }
#else
    void* dataLocation() const { ASSERT_VALID_CODE_POINTER(m_value); return m_value; }
#endif

    bool operator!() const
    {
        return !m_value;
    }

private:
    void* m_value;
};

// MacroAssemblerCodeRef:
//
// A reference to a section of JIT generated code.  A CodeRef consists of a
// pointer to the code, and a ref pointer to the pool from within which it
// was allocated.
class MacroAssemblerCodeRef {
private:
    // This is private because it's dangerous enough that we want uses of it
    // to be easy to find - hence the static create method below.
    explicit MacroAssemblerCodeRef(MacroAssemblerCodePtr codePtr)
        : m_codePtr(codePtr)
    {
        ASSERT(m_codePtr);
    }

public:
    MacroAssemblerCodeRef()
    {
    }

    MacroAssemblerCodeRef(PassRefPtr<ExecutableMemoryHandle> executableMemory)
        : m_codePtr(executableMemory->start())
        , m_executableMemory(executableMemory)
    {
        ASSERT(m_executableMemory->isManaged());
        ASSERT(m_executableMemory->start());
        ASSERT(m_codePtr);
    }
    
    // Use this only when you know that the codePtr refers to code that is
    // already being kept alive through some other means. Typically this means
    // that codePtr is immortal.
    static MacroAssemblerCodeRef createSelfManagedCodeRef(MacroAssemblerCodePtr codePtr)
    {
        return MacroAssemblerCodeRef(codePtr);
    }
    
    ExecutableMemoryHandle* executableMemory() const
    {
        return m_executableMemory.get();
    }
    
    MacroAssemblerCodePtr code() const
    {
        return m_codePtr;
    }
    
    size_t size() const
    {
        if (!m_executableMemory)
            return 0;
        return m_executableMemory->sizeInBytes();
    }
    
    bool operator!() const { return !m_codePtr; }

private:
    MacroAssemblerCodePtr m_codePtr;
    RefPtr<ExecutableMemoryHandle> m_executableMemory;
};

} // namespace JSC

#endif // ENABLE(ASSEMBLER)

#endif // MacroAssemblerCodeRef_h
