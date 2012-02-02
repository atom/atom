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

#ifndef DFGCorrectableJumpPoint_h
#define DFGCorrectableJumpPoint_h

#if ENABLE(DFG_JIT)

#include "LinkBuffer.h"
#include "MacroAssembler.h"

namespace JSC { namespace DFG {

// This is a type-safe union of MacroAssembler::Jump and CodeLocationJump.
// Furthermore, it supports the notion of branching (possibly conditionally, but
// also possibly jumping unconditionally) to an out-of-line patchable jump.
// Thus it goes through three states:
//
// 1) Label of unpatchable branch or jump (i.e. MacroAssembler::Jump).
// 2) Label of patchable jump (i.e. MacroAssembler::Jump).
// 3) Corrected post-linking label of patchable jump (i.e. CodeLocationJump).
//
// The setting of state (1) corresponds to planting the in-line unpatchable
// branch or jump. The state transition (1)->(2) corresponds to linking the
// in-line branch or jump to the out-of-line patchable jump, and recording
// the latter's label. The state transition (2)->(3) corresponds to recording
// the out-of-line patchable jump's location after branch compaction has
// completed.
//
// You can also go directly from the first state to the third state, if you
// wish to use this class for in-line patchable jumps.

class CorrectableJumpPoint {
public:
    CorrectableJumpPoint(MacroAssembler::Jump check)
        : m_codeOffset(check.m_label.m_offset)
#ifndef NDEBUG
        , m_mode(InitialJump)
#endif
    {
#if CPU(ARM_THUMB2)
        m_type = check.m_type;
        m_condition = check.m_condition;
#endif
    }
    
    void switchToLateJump(MacroAssembler::Jump check)
    {
#ifndef NDEBUG
        ASSERT(m_mode == InitialJump);
        m_mode = LateJump;
#endif
        // Late jumps should only ever be real jumps.
#if CPU(ARM_THUMB2)
        ASSERT(check.m_type == ARMv7Assembler::JumpNoConditionFixedSize);
        ASSERT(check.m_condition == ARMv7Assembler::ConditionInvalid);
        m_type = ARMv7Assembler::JumpNoConditionFixedSize;
        m_condition = ARMv7Assembler::ConditionInvalid;
#endif
        m_codeOffset = check.m_label.m_offset;
    }
    
    void correctInitialJump(LinkBuffer& linkBuffer)
    {
        ASSERT(m_mode == InitialJump);
#if CPU(ARM_THUMB2)
        ASSERT(m_type == ARMv7Assembler::JumpNoConditionFixedSize);
        ASSERT(m_condition == ARMv7Assembler::ConditionInvalid);
#endif
        correctJump(linkBuffer);
    }
    
    void correctLateJump(LinkBuffer& linkBuffer)
    {
        ASSERT(m_mode == LateJump);
        correctJump(linkBuffer);
    }
    
    MacroAssembler::Jump initialJump() const
    {
        ASSERT(m_mode == InitialJump);
        return getJump();
    }
    
    MacroAssembler::Jump lateJump() const
    {
        ASSERT(m_mode == LateJump);
        return getJump();
    }
    
    CodeLocationJump codeLocationForRepatch(CodeBlock*) const;
    
private:
    void correctJump(LinkBuffer& linkBuffer)
    {
#ifndef NDEBUG
        m_mode = CorrectedJump;
#endif
        MacroAssembler::Label label;
        label.m_label.m_offset = m_codeOffset;
        m_codeOffset = linkBuffer.offsetOf(label);
    }
    
    MacroAssembler::Jump getJump() const
    {
        MacroAssembler::Jump jump;
        jump.m_label.m_offset = m_codeOffset;
#if CPU(ARM_THUMB2)
        jump.m_type = m_type;
        jump.m_condition = m_condition;
#endif
        return jump;
    }
    
    unsigned m_codeOffset;

#if CPU(ARM_THUMB2)
    ARMv7Assembler::JumpType m_type : 8;
    ARMv7Assembler::Condition m_condition : 8;
#endif

#ifndef NDEBUG
    enum Mode {
        InitialJump,
        LateJump,
        CorrectedJump
    };

    Mode m_mode;
#endif
};

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGCorrectableJumpPoint_h
