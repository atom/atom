/*
 * Copyright (C) 2012 Apple Inc. All rights reserved.
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

#ifndef JITDriver_h
#define JITDriver_h

#include <wtf/Platform.h>

#if ENABLE(JIT)

#include "BytecodeGenerator.h"
#include "DFGDriver.h"
#include "JIT.h"

namespace JSC {

template<typename CodeBlockType>
inline bool jitCompileIfAppropriate(JSGlobalData& globalData, OwnPtr<CodeBlockType>& codeBlock, JITCode& jitCode, JITCode::JITType jitType)
{
    if (!globalData.canUseJIT())
        return true;
    
    bool dfgCompiled = false;
    if (jitType == JITCode::DFGJIT)
        dfgCompiled = DFG::tryCompile(globalData, codeBlock.get(), jitCode);
    if (dfgCompiled) {
        if (codeBlock->alternative())
            codeBlock->alternative()->unlinkIncomingCalls();
    } else {
        if (codeBlock->alternative()) {
            codeBlock = static_pointer_cast<CodeBlockType>(codeBlock->releaseAlternative());
            return false;
        }
        jitCode = JIT::compile(&globalData, codeBlock.get());
    }
#if !ENABLE(OPCODE_SAMPLING)
    if (!BytecodeGenerator::dumpsGeneratedCode())
        codeBlock->handleBytecodeDiscardingOpportunity();
#endif
    codeBlock->setJITCode(jitCode, MacroAssemblerCodePtr());
    
    return true;
}

inline bool jitCompileFunctionIfAppropriate(JSGlobalData& globalData, OwnPtr<FunctionCodeBlock>& codeBlock, JITCode& jitCode, MacroAssemblerCodePtr& jitCodeWithArityCheck, SharedSymbolTable*& symbolTable, JITCode::JITType jitType)
{
    if (!globalData.canUseJIT())
        return true;
    
    bool dfgCompiled = false;
    if (jitType == JITCode::DFGJIT)
        dfgCompiled = DFG::tryCompileFunction(globalData, codeBlock.get(), jitCode, jitCodeWithArityCheck);
    if (dfgCompiled) {
        if (codeBlock->alternative())
            codeBlock->alternative()->unlinkIncomingCalls();
    } else {
        if (codeBlock->alternative()) {
            codeBlock = static_pointer_cast<FunctionCodeBlock>(codeBlock->releaseAlternative());
            symbolTable = codeBlock->sharedSymbolTable();
            return false;
        }
        jitCode = JIT::compile(&globalData, codeBlock.get(), &jitCodeWithArityCheck);
    }
#if !ENABLE(OPCODE_SAMPLING)
    if (!BytecodeGenerator::dumpsGeneratedCode())
        codeBlock->handleBytecodeDiscardingOpportunity();
#endif
    
    codeBlock->setJITCode(jitCode, jitCodeWithArityCheck);
    
    return true;
}

} // namespace JSC

#endif // ENABLE(JIT)

#endif // JITDriver_h

