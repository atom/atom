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

#ifndef DFGOSRExitCompiler_h
#define DFGOSRExitCompiler_h

#include <wtf/Platform.h>

#if ENABLE(DFG_JIT)

#include "DFGAssemblyHelpers.h"
#include "DFGOSRExit.h"
#include "DFGOperations.h"

namespace JSC {

class ExecState;

namespace DFG {

class OSRExitCompiler {
public:
    OSRExitCompiler(AssemblyHelpers& jit)
        : m_jit(jit)
    {
    }
    
    void compileExit(const OSRExit&, SpeculationRecovery*);

private:
#if !ASSERT_DISABLED
    static unsigned badIndex() { return static_cast<unsigned>(-1); };
#endif
    
    void initializePoisoned(unsigned size)
    {
#if ASSERT_DISABLED
        m_poisonScratchIndices.resize(size);
#else
        m_poisonScratchIndices.fill(badIndex(), size);
#endif
    }
    
    unsigned poisonIndex(unsigned index)
    {
        unsigned result = m_poisonScratchIndices[index];
        ASSERT(result != badIndex());
        return result;
    }
    
    AssemblyHelpers& m_jit;
    Vector<unsigned> m_poisonScratchIndices;
};

extern "C" {
void DFG_OPERATION compileOSRExit(ExecState*);
}

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGOSRExitCompiler_h
