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

#ifndef ExecutableAllocator_h
#define ExecutableAllocator_h
#include <stddef.h> // for ptrdiff_t
#include <limits>
#include <wtf/Assertions.h>
#include <wtf/MetaAllocatorHandle.h>
#include <wtf/PageAllocation.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/UnusedParam.h>
#include <wtf/Vector.h>

#if OS(IOS)
#include <libkern/OSCacheControl.h>
#endif

#if OS(IOS) || OS(QNX)
#include <sys/mman.h>
#endif

#if CPU(MIPS) && OS(LINUX)
#include <sys/cachectl.h>
#endif

#if CPU(SH4) && OS(LINUX)
#include <asm/cachectl.h>
#include <asm/unistd.h>
#include <sys/syscall.h>
#include <unistd.h>
#endif

#if OS(WINCE)
// From pkfuncs.h (private header file from the Platform Builder)
#define CACHE_SYNC_ALL 0x07F
extern "C" __declspec(dllimport) void CacheRangeFlush(LPVOID pAddr, DWORD dwLength, DWORD dwFlags);
#endif

#define JIT_ALLOCATOR_LARGE_ALLOC_SIZE (pageSize() * 4)

#if ENABLE(ASSEMBLER_WX_EXCLUSIVE)
#define PROTECTION_FLAGS_RW (PROT_READ | PROT_WRITE)
#define PROTECTION_FLAGS_RX (PROT_READ | PROT_EXEC)
#define EXECUTABLE_POOL_WRITABLE false
#else
#define EXECUTABLE_POOL_WRITABLE true
#endif

namespace JSC {

class JSGlobalData;
void releaseExecutableMemory(JSGlobalData&);

inline size_t roundUpAllocationSize(size_t request, size_t granularity)
{
    if ((std::numeric_limits<size_t>::max() - granularity) <= request)
        CRASH(); // Allocation is too large
    
    // Round up to next page boundary
    size_t size = request + (granularity - 1);
    size = size & ~(granularity - 1);
    ASSERT(size >= request);
    return size;
}

}

#if ENABLE(JIT) && ENABLE(ASSEMBLER)

namespace JSC {

typedef WTF::MetaAllocatorHandle ExecutableMemoryHandle;

class ExecutableAllocator {
    enum ProtectionSetting { Writable, Executable };

public:
    ExecutableAllocator(JSGlobalData&);
    
    static void initializeAllocator();

    bool isValid() const;

    static bool underMemoryPressure();
    
#if ENABLE(META_ALLOCATOR_PROFILE)
    static void dumpProfile();
#else
    static void dumpProfile() { }
#endif

    PassRefPtr<ExecutableMemoryHandle> allocate(JSGlobalData&, size_t sizeInBytes, void* ownerUID);

#if ENABLE(ASSEMBLER_WX_EXCLUSIVE)
    static void makeWritable(void* start, size_t size)
    {
        reprotectRegion(start, size, Writable);
    }

    static void makeExecutable(void* start, size_t size)
    {
        reprotectRegion(start, size, Executable);
    }
#else
    static void makeWritable(void*, size_t) {}
    static void makeExecutable(void*, size_t) {}
#endif

#if CPU(X86) || CPU(X86_64)
    static void cacheFlush(void*, size_t)
    {
    }
#elif CPU(MIPS)
    static void cacheFlush(void* code, size_t size)
    {
#if GCC_VERSION_AT_LEAST(4, 3, 0)
#if WTF_MIPS_ISA_REV(2) && !GCC_VERSION_AT_LEAST(4, 4, 3)
        int lineSize;
        asm("rdhwr %0, $1" : "=r" (lineSize));
        //
        // Modify "start" and "end" to avoid GCC 4.3.0-4.4.2 bug in
        // mips_expand_synci_loop that may execute synci one more time.
        // "start" points to the fisrt byte of the cache line.
        // "end" points to the last byte of the line before the last cache line.
        // Because size is always a multiple of 4, this is safe to set
        // "end" to the last byte.
        //
        intptr_t start = reinterpret_cast<intptr_t>(code) & (-lineSize);
        intptr_t end = ((reinterpret_cast<intptr_t>(code) + size - 1) & (-lineSize)) - 1;
        __builtin___clear_cache(reinterpret_cast<char*>(start), reinterpret_cast<char*>(end));
#else
        intptr_t end = reinterpret_cast<intptr_t>(code) + size;
        __builtin___clear_cache(reinterpret_cast<char*>(code), reinterpret_cast<char*>(end));
#endif
#else
        _flush_cache(reinterpret_cast<char*>(code), size, BCACHE);
#endif
    }
#elif CPU(ARM_THUMB2) && OS(IOS)
    static void cacheFlush(void* code, size_t size)
    {
        sys_cache_control(kCacheFunctionPrepareForExecution, code, size);
    }
#elif CPU(ARM_THUMB2) && OS(LINUX)
    static void cacheFlush(void* code, size_t size)
    {
        asm volatile (
            "push    {r7}\n"
            "mov     r0, %0\n"
            "mov     r1, %1\n"
            "movw    r7, #0x2\n"
            "movt    r7, #0xf\n"
            "movs    r2, #0x0\n"
            "svc     0x0\n"
            "pop     {r7}\n"
            :
            : "r" (code), "r" (reinterpret_cast<char*>(code) + size)
            : "r0", "r1", "r2");
    }
#elif CPU(ARM_TRADITIONAL) && OS(LINUX) && COMPILER(RVCT)
    static __asm void cacheFlush(void* code, size_t size);
#elif CPU(ARM_TRADITIONAL) && OS(LINUX) && COMPILER(GCC)
    static void cacheFlush(void* code, size_t size)
    {
        asm volatile (
            "push    {r7}\n"
            "mov     r0, %0\n"
            "mov     r1, %1\n"
            "mov     r7, #0xf0000\n"
            "add     r7, r7, #0x2\n"
            "mov     r2, #0x0\n"
            "svc     0x0\n"
            "pop     {r7}\n"
            :
            : "r" (code), "r" (reinterpret_cast<char*>(code) + size)
            : "r0", "r1", "r2");
    }
#elif OS(WINCE)
    static void cacheFlush(void* code, size_t size)
    {
        CacheRangeFlush(code, size, CACHE_SYNC_ALL);
    }
#elif CPU(SH4) && OS(LINUX)
    static void cacheFlush(void* code, size_t size)
    {
#ifdef CACHEFLUSH_D_L2
        syscall(__NR_cacheflush, reinterpret_cast<unsigned>(code), size, CACHEFLUSH_D_WB | CACHEFLUSH_I | CACHEFLUSH_D_L2);
#else
        syscall(__NR_cacheflush, reinterpret_cast<unsigned>(code), size, CACHEFLUSH_D_WB | CACHEFLUSH_I);
#endif
    }
#elif OS(QNX)
    static void cacheFlush(void* code, size_t size)
    {
#if !ENABLE(ASSEMBLER_WX_EXCLUSIVE)
        msync(code, size, MS_INVALIDATE_ICACHE);
#else
        UNUSED_PARAM(code);
        UNUSED_PARAM(size);
#endif
    }
#else
    #error "The cacheFlush support is missing on this platform."
#endif
    static size_t committedByteCount();

private:

#if ENABLE(ASSEMBLER_WX_EXCLUSIVE)
    static void reprotectRegion(void*, size_t, ProtectionSetting);
#endif
};

} // namespace JSC

#endif // ENABLE(JIT) && ENABLE(ASSEMBLER)

#endif // !defined(ExecutableAllocator)
