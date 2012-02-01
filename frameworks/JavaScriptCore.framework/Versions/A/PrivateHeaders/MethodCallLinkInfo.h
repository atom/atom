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

#ifndef MethodCallLinkInfo_h
#define MethodCallLinkInfo_h

#include "CodeLocation.h"
#include "JITCode.h"
#include "JITWriteBarrier.h"
#include <wtf/Platform.h>

namespace JSC {

#if ENABLE(JIT)

class RepatchBuffer;

struct MethodCallLinkInfo {
    MethodCallLinkInfo()
        : seen(false)
    {
    }

    bool seenOnce()
    {
        return seen;
    }

    void setSeen()
    {
        seen = true;
    }
        
    void reset(RepatchBuffer&, JITCode::JITType);

    unsigned bytecodeIndex;
    CodeLocationCall callReturnLocation;
    JITWriteBarrier<Structure> cachedStructure;
    JITWriteBarrier<Structure> cachedPrototypeStructure;
    // We'd like this to actually be JSFunction, but InternalFunction and JSFunction
    // don't have a common parent class and we allow specialisation on both
    JITWriteBarrier<JSObject> cachedFunction;
    JITWriteBarrier<JSObject> cachedPrototype;
    bool seen;
};

inline void* getMethodCallLinkInfoReturnLocation(MethodCallLinkInfo* methodCallLinkInfo)
{
    return methodCallLinkInfo->callReturnLocation.executableAddress();
}

inline unsigned getMethodCallLinkInfoBytecodeIndex(MethodCallLinkInfo* methodCallLinkInfo)
{
    return methodCallLinkInfo->bytecodeIndex;
}

#endif // ENABLE(JIT)

} // namespace JSC

#endif // MethodCallLinkInfo_h
