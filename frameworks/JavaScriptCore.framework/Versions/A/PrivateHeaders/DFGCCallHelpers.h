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

#ifndef DFGCCallHelpers_h
#define DFGCCallHelpers_h

#include <wtf/Platform.h>

#if ENABLE(DFG_JIT)

#include "DFGAssemblyHelpers.h"
#include "DFGGPRInfo.h"

namespace JSC { namespace DFG {

class CCallHelpers : public AssemblyHelpers {
public:
    CCallHelpers(JSGlobalData* globalData, CodeBlock* codeBlock)
        : AssemblyHelpers(globalData, codeBlock)
    {
    }

    // These methods used to sort arguments into the correct registers.
    // On X86 we use cdecl calling conventions, which pass all arguments on the
    // stack. On other architectures we may need to sort values into the
    // correct registers.
#if !NUMBER_OF_ARGUMENT_REGISTERS
    unsigned m_callArgumentOffset;
    void resetCallArguments() { m_callArgumentOffset = 0; }

    // These methods are using internally to implement the callOperation methods.
    void addCallArgument(GPRReg value)
    {
        poke(value, m_callArgumentOffset++);
    }
    void addCallArgument(TrustedImm32 imm)
    {
        poke(imm, m_callArgumentOffset++);
    }
    void addCallArgument(TrustedImmPtr pointer)
    {
        poke(pointer, m_callArgumentOffset++);
    }
    void addCallArgument(FPRReg value)
    {
        storeDouble(value, Address(stackPointerRegister, m_callArgumentOffset * sizeof(void*)));
        m_callArgumentOffset += sizeof(double) / sizeof(void*);
    }

    ALWAYS_INLINE void setupArguments(FPRReg arg1)
    {
        resetCallArguments();
        addCallArgument(arg1);
    }

    ALWAYS_INLINE void setupArguments(FPRReg arg1, FPRReg arg2)
    {
        resetCallArguments();
        addCallArgument(arg1);
        addCallArgument(arg2);
    }

    ALWAYS_INLINE void setupArguments(GPRReg arg1, GPRReg arg2)
    {
        resetCallArguments();
        addCallArgument(arg1);
        addCallArgument(arg2);
    }

    ALWAYS_INLINE void setupArgumentsExecState()
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImmPtr arg1)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, TrustedImmPtr arg2)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImm32 arg1, TrustedImm32 arg2)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImmPtr arg1, TrustedImmPtr arg2)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, TrustedImmPtr arg3)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, TrustedImm32 arg2, TrustedImmPtr arg3)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, TrustedImmPtr arg2, TrustedImmPtr arg3)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3, GPRReg arg4)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
        addCallArgument(arg4);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3, TrustedImmPtr arg4)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
        addCallArgument(arg4);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, TrustedImm32 arg3, TrustedImm32 arg4)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
        addCallArgument(arg4);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImm32 arg1, TrustedImm32 arg2, GPRReg arg3, GPRReg arg4)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
        addCallArgument(arg4);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3, GPRReg arg4, GPRReg arg5)
    {
        resetCallArguments();
        addCallArgument(GPRInfo::callFrameRegister);
        addCallArgument(arg1);
        addCallArgument(arg2);
        addCallArgument(arg3);
        addCallArgument(arg4);
        addCallArgument(arg5);
    }
#endif // !NUMBER_OF_ARGUMENT_REGISTERS
    // These methods are suitable for any calling convention that provides for
    // at least 4 argument registers, e.g. X86_64, ARMv7.
#if NUMBER_OF_ARGUMENT_REGISTERS >= 4
    template<GPRReg destA, GPRReg destB>
    void setupTwoStubArgs(GPRReg srcA, GPRReg srcB)
    {
        // Assuming that srcA != srcB, there are 7 interesting states the registers may be in:
        // (1) both are already in arg regs, the right way around.
        // (2) both are already in arg regs, the wrong way around.
        // (3) neither are currently in arg registers.
        // (4) srcA in in its correct reg.
        // (5) srcA in in the incorrect reg.
        // (6) srcB in in its correct reg.
        // (7) srcB in in the incorrect reg.
        //
        // The trivial approach is to simply emit two moves, to put srcA in place then srcB in
        // place (the MacroAssembler will omit redundant moves). This apporach will be safe in
        // cases 1, 3, 4, 5, 6, and in cases where srcA==srcB. The two problem cases are 2
        // (requires a swap) and 7 (must move srcB first, to avoid trampling.)

        if (srcB != destA) {
            // Handle the easy cases - two simple moves.
            move(srcA, destA);
            move(srcB, destB);
        } else if (srcA != destB) {
            // Handle the non-swap case - just put srcB in place first.
            move(srcB, destB);
            move(srcA, destA);
        } else
            swap(destA, destB);
    }
#if CPU(X86_64)
    template<FPRReg destA, FPRReg destB>
    void setupTwoStubArgs(FPRReg srcA, FPRReg srcB)
    {
        // Assuming that srcA != srcB, there are 7 interesting states the registers may be in:
        // (1) both are already in arg regs, the right way around.
        // (2) both are already in arg regs, the wrong way around.
        // (3) neither are currently in arg registers.
        // (4) srcA in in its correct reg.
        // (5) srcA in in the incorrect reg.
        // (6) srcB in in its correct reg.
        // (7) srcB in in the incorrect reg.
        //
        // The trivial approach is to simply emit two moves, to put srcA in place then srcB in
        // place (the MacroAssembler will omit redundant moves). This apporach will be safe in
        // cases 1, 3, 4, 5, 6, and in cases where srcA==srcB. The two problem cases are 2
        // (requires a swap) and 7 (must move srcB first, to avoid trampling.)

        if (srcB != destA) {
            // Handle the easy cases - two simple moves.
            moveDouble(srcA, destA);
            moveDouble(srcB, destB);
            return;
        }
        
        if (srcA != destB) {
            // Handle the non-swap case - just put srcB in place first.
            moveDouble(srcB, destB);
            moveDouble(srcA, destA);
            return;
        }

        ASSERT(srcB == destA && srcA == destB);
        // Need to swap; pick a temporary register.
        FPRReg temp;
        if (destA != FPRInfo::argumentFPR3 && destA != FPRInfo::argumentFPR3)
            temp = FPRInfo::argumentFPR3;
        else if (destA != FPRInfo::argumentFPR2 && destA != FPRInfo::argumentFPR2)
            temp = FPRInfo::argumentFPR2;
        else {
            ASSERT(destA != FPRInfo::argumentFPR1 && destA != FPRInfo::argumentFPR1);
            temp = FPRInfo::argumentFPR1;
        }
        moveDouble(destA, temp);
        moveDouble(destB, destA);
        moveDouble(temp, destB);
    }
#endif
    void setupStubArguments(GPRReg arg1, GPRReg arg2)
    {
        setupTwoStubArgs<GPRInfo::argumentGPR1, GPRInfo::argumentGPR2>(arg1, arg2);
    }
    void setupStubArguments(GPRReg arg1, GPRReg arg2, GPRReg arg3)
    {
        // If neither of arg2/arg3 are in our way, then we can move arg1 into place.
        // Then we can use setupTwoStubArgs to fix arg2/arg3.
        if (arg2 != GPRInfo::argumentGPR1 && arg3 != GPRInfo::argumentGPR1) {
            move(arg1, GPRInfo::argumentGPR1);
            setupTwoStubArgs<GPRInfo::argumentGPR2, GPRInfo::argumentGPR3>(arg2, arg3);
            return;
        }

        // If neither of arg1/arg3 are in our way, then we can move arg2 into place.
        // Then we can use setupTwoStubArgs to fix arg1/arg3.
        if (arg1 != GPRInfo::argumentGPR2 && arg3 != GPRInfo::argumentGPR2) {
            move(arg2, GPRInfo::argumentGPR2);
            setupTwoStubArgs<GPRInfo::argumentGPR1, GPRInfo::argumentGPR3>(arg1, arg3);
            return;
        }

        // If neither of arg1/arg2 are in our way, then we can move arg3 into place.
        // Then we can use setupTwoStubArgs to fix arg1/arg2.
        if (arg1 != GPRInfo::argumentGPR3 && arg2 != GPRInfo::argumentGPR3) {
            move(arg3, GPRInfo::argumentGPR3);
            setupTwoStubArgs<GPRInfo::argumentGPR1, GPRInfo::argumentGPR2>(arg1, arg2);
            return;
        }

        // If we get here, we haven't been able to move any of arg1/arg2/arg3.
        // Since all three are blocked, then all three must already be in the argument register.
        // But are they in the right ones?

        // First, ensure arg1 is in place.
        if (arg1 != GPRInfo::argumentGPR1) {
            swap(arg1, GPRInfo::argumentGPR1);

            // If arg1 wasn't in argumentGPR1, one of arg2/arg3 must be.
            ASSERT(arg2 == GPRInfo::argumentGPR1 || arg3 == GPRInfo::argumentGPR1);
            // If arg2 was in argumentGPR1 it no longer is (due to the swap).
            // Otherwise arg3 must have been. Mark him as moved.
            if (arg2 == GPRInfo::argumentGPR1)
                arg2 = arg1;
            else
                arg3 = arg1;
        }

        // Either arg2 & arg3 need swapping, or we're all done.
        ASSERT((arg2 == GPRInfo::argumentGPR2 || arg3 == GPRInfo::argumentGPR3)
            || (arg2 == GPRInfo::argumentGPR3 || arg3 == GPRInfo::argumentGPR2));

        if (arg2 != GPRInfo::argumentGPR2)
            swap(GPRInfo::argumentGPR2, GPRInfo::argumentGPR3);
    }

#if CPU(X86_64)
    ALWAYS_INLINE void setupArguments(FPRReg arg1)
    {
        moveDouble(arg1, FPRInfo::argumentFPR0);
    }

    ALWAYS_INLINE void setupArguments(FPRReg arg1, FPRReg arg2)
    {
        setupTwoStubArgs<FPRInfo::argumentFPR0, FPRInfo::argumentFPR1>(arg1, arg2);
    }
#else
    ALWAYS_INLINE void setupArguments(FPRReg arg1)
    {
        assembler().vmov(GPRInfo::argumentGPR0, GPRInfo::argumentGPR1, arg1);
    }

    ALWAYS_INLINE void setupArguments(FPRReg arg1, FPRReg arg2)
    {
        assembler().vmov(GPRInfo::argumentGPR0, GPRInfo::argumentGPR1, arg1);
        assembler().vmov(GPRInfo::argumentGPR2, GPRInfo::argumentGPR3, arg2);
    }
#endif

    ALWAYS_INLINE void setupArguments(GPRReg arg1, GPRReg arg2)
    {
        setupTwoStubArgs<GPRInfo::argumentGPR0, GPRInfo::argumentGPR1>(arg1, arg2);
    }

    ALWAYS_INLINE void setupArgumentsExecState()
    {
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImmPtr arg1)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2)
    {
        setupStubArguments(arg1, arg2);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, TrustedImmPtr arg2)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(arg2, GPRInfo::argumentGPR2);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImmPtr arg1, GPRReg arg2)
    {
        move(arg2, GPRInfo::argumentGPR2); // Move this first, so setting arg1 does not trample!
        move(arg1, GPRInfo::argumentGPR1);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImm32 arg1, TrustedImm32 arg2)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(arg2, GPRInfo::argumentGPR2);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImmPtr arg1, TrustedImmPtr arg2)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(arg2, GPRInfo::argumentGPR2);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3)
    {
        setupStubArguments(arg1, arg2, arg3);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, TrustedImm32 arg3)
    {
        setupStubArguments(arg1, arg2);
        move(arg3, GPRInfo::argumentGPR3);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, TrustedImm32 arg2, TrustedImmPtr arg3)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(arg2, GPRInfo::argumentGPR2);
        move(arg3, GPRInfo::argumentGPR3);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, TrustedImmPtr arg2, TrustedImmPtr arg3)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(arg2, GPRInfo::argumentGPR2);
        move(arg3, GPRInfo::argumentGPR3);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, TrustedImmPtr arg3)
    {
        setupStubArguments(arg1, arg2);
        move(arg3, GPRInfo::argumentGPR3);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImm32 arg1, TrustedImm32 arg2, GPRReg arg3)
    {
        move(arg1, GPRInfo::argumentGPR1);
        move(arg2, GPRInfo::argumentGPR2);
        move(arg3, GPRInfo::argumentGPR3);
        move(GPRInfo::callFrameRegister, GPRInfo::argumentGPR0);
    }

#endif // NUMBER_OF_ARGUMENT_REGISTERS >= 4
    // These methods are suitable for any calling convention that provides for
    // exactly 4 argument registers, e.g. ARMv7.
#if NUMBER_OF_ARGUMENT_REGISTERS == 4
    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3, GPRReg arg4)
    {
        poke(arg4);
        setupArgumentsWithExecState(arg1, arg2, arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, TrustedImm32 arg3, TrustedImm32 arg4)
    {
        poke(arg4);
        setupArgumentsWithExecState(arg1, arg2, arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(TrustedImm32 arg1, TrustedImm32 arg2, GPRReg arg3, GPRReg arg4)
    {
        poke(arg4);
        setupArgumentsWithExecState(arg1, arg2, arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3, TrustedImmPtr arg4)
    {
        poke(arg4);
        setupArgumentsWithExecState(arg1, arg2, arg3);
    }

    ALWAYS_INLINE void setupArgumentsWithExecState(GPRReg arg1, GPRReg arg2, GPRReg arg3, GPRReg arg4, GPRReg arg5)
    {
        poke(arg5, 1);
        poke(arg4);
        setupArgumentsWithExecState(arg1, arg2, arg3);
    }
#endif // NUMBER_OF_ARGUMENT_REGISTERS == 4

    void setupResults(GPRReg destA, GPRReg destB)
    {
        GPRReg srcA = GPRInfo::returnValueGPR;
        GPRReg srcB = GPRInfo::returnValueGPR2;

        if (srcB != destA) {
            // Handle the easy cases - two simple moves.
            move(srcA, destA);
            move(srcB, destB);
        } else if (srcA != destB) {
            // Handle the non-swap case - just put srcB in place first.
            move(srcB, destB);
            move(srcA, destA);
        } else
            swap(destA, destB);
    }
};

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGCCallHelpers_h

