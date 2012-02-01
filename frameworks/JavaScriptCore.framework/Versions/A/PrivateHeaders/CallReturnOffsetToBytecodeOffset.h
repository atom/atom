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

#ifndef CallReturnOffsetToBytecodeOffset_h
#define CallReturnOffsetToBytecodeOffset_h

#include <wtf/Platform.h>

namespace JSC {

#if ENABLE(JIT)
// This structure is used to map from a call return location
// (given as an offset in bytes into the JIT code) back to
// the bytecode index of the corresponding bytecode operation.
// This is then used to look up the corresponding handler.
// FIXME: This should be made inlining aware! Currently it isn't
// because we never inline code that has exception handlers.
struct CallReturnOffsetToBytecodeOffset {
    CallReturnOffsetToBytecodeOffset(unsigned callReturnOffset, unsigned bytecodeOffset)
        : callReturnOffset(callReturnOffset)
        , bytecodeOffset(bytecodeOffset)
    {
    }

    unsigned callReturnOffset;
    unsigned bytecodeOffset;
};

inline unsigned getCallReturnOffset(CallReturnOffsetToBytecodeOffset* pc)
{
    return pc->callReturnOffset;
}
#endif

} // namespace JSC

#endif // CallReturnOffsetToBytecodeOffset_h

