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

#ifndef DFGOSRExit_h
#define DFGOSRExit_h

#include <wtf/Platform.h>

#if ENABLE(DFG_JIT)

#include "CodeOrigin.h"
#include "DFGCommon.h"
#include "DFGCorrectableJumpPoint.h"
#include "DFGExitProfile.h"
#include "DFGGPRInfo.h"
#include "DFGOperands.h"
#include "MacroAssembler.h"
#include "ValueProfile.h"
#include "ValueRecovery.h"
#include <wtf/Vector.h>

namespace JSC { namespace DFG {

class SpeculativeJIT;

// This enum describes the types of additional recovery that
// may need be performed should a speculation check fail.
enum SpeculationRecoveryType {
    SpeculativeAdd,
    BooleanSpeculationCheck
};

// === SpeculationRecovery ===
//
// This class provides additional information that may be associated with a
// speculation check - for example 
class SpeculationRecovery {
public:
    SpeculationRecovery(SpeculationRecoveryType type, GPRReg dest, GPRReg src)
        : m_type(type)
        , m_dest(dest)
        , m_src(src)
    {
    }

    SpeculationRecoveryType type() { return m_type; }
    GPRReg dest() { return m_dest; }
    GPRReg src() { return m_src; }

private:
    // Indicates the type of additional recovery to be performed.
    SpeculationRecoveryType m_type;
    // different recovery types may required different additional information here.
    GPRReg m_dest;
    GPRReg m_src;
};

// === OSRExit ===
//
// This structure describes how to exit the speculative path by
// going into baseline code.
struct OSRExit {
    OSRExit(ExitKind, JSValueSource, ValueProfile*, MacroAssembler::Jump, SpeculativeJIT*, unsigned recoveryIndex = 0);
    
    MacroAssemblerCodeRef m_code;
    
    JSValueSource m_jsValueSource;
    ValueProfile* m_valueProfile;
    
    CorrectableJumpPoint m_check;
    NodeIndex m_nodeIndex;
    CodeOrigin m_codeOrigin;
    
    unsigned m_recoveryIndex;
    
    ExitKind m_kind;
    uint32_t m_count;
    
    // Convenient way of iterating over ValueRecoveries while being
    // generic over argument versus variable.
    int numberOfRecoveries() const { return m_arguments.size() + m_variables.size(); }
    const ValueRecovery& valueRecovery(int index) const
    {
        if (index < (int)m_arguments.size())
            return m_arguments[index];
        return m_variables[index - m_arguments.size()];
    }
    ValueRecovery& valueRecoveryForOperand(int operand)
    {
        if (operandIsArgument(operand))
            return m_arguments[operandToArgument(operand)];
        return m_variables[operand];
    }
    bool isArgument(int index) const { return index < (int)m_arguments.size(); }
    bool isVariable(int index) const { return !isArgument(index); }
    int argumentForIndex(int index) const
    {
        return index;
    }
    int variableForIndex(int index) const
    {
        return index - m_arguments.size();
    }
    int operandForIndex(int index) const
    {
        if (index < (int)m_arguments.size())
            return operandToArgument(index);
        return index - m_arguments.size();
    }
    
    bool considerAddingAsFrequentExitSite(CodeBlock* dfgCodeBlock, CodeBlock* profiledCodeBlock)
    {
        if (!m_count || !exitKindIsCountable(m_kind))
            return false;
        return considerAddingAsFrequentExitSiteSlow(dfgCodeBlock, profiledCodeBlock);
    }
    
#ifndef NDEBUG
    void dump(FILE* out) const;
#endif
    
    Vector<ValueRecovery, 0> m_arguments;
    Vector<ValueRecovery, 0> m_variables;
    int m_lastSetOperand;

private:
    bool considerAddingAsFrequentExitSiteSlow(CodeBlock* dfgCodeBlock, CodeBlock* profiledCodeBlock);
};

#if DFG_ENABLE(VERBOSE_SPECULATION_FAILURE)
struct SpeculationFailureDebugInfo {
    CodeBlock* codeBlock;
    NodeIndex nodeIndex;
};
#endif

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGOSRExit_h

