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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef WriteBarrierSupport_h
#define WriteBarrierSupport_h

#include "SamplingCounter.h"
#include <wtf/Assertions.h>

namespace JSC {

// This allows the JIT to distinguish between uses of the barrier for different
// kinds of writes. This is used by the JIT for profiling, and may be appropriate
// for allowing the GC implementation to specialize the JIT's write barrier code
// for different kinds of target objects.
enum WriteBarrierUseKind {
    // This allows specialization for access to the property storage (either
    // array element or property), but not for any other kind of property
    // accesses (such as writes that are a consequence of setter execution).
    WriteBarrierForPropertyAccess,
    
    // This allows specialization for variable accesses (such as global or
    // scoped variables).
    WriteBarrierForVariableAccess,
    
    // This captures all other forms of write barriers. It should always be
    // correct to use a generic access write barrier, even when storing to
    // properties. Hence, if optimization is not necessary, it is preferable
    // to just use a generic access.
    WriteBarrierForGenericAccess
};

class WriteBarrierCounters {
private:
    WriteBarrierCounters() { }

public:
#if ENABLE(WRITE_BARRIER_PROFILING)
    static GlobalSamplingCounter usesWithBarrierFromCpp;
    static GlobalSamplingCounter usesWithoutBarrierFromCpp;
    static GlobalSamplingCounter usesWithBarrierFromJit;
    static GlobalSamplingCounter usesForPropertiesFromJit;
    static GlobalSamplingCounter usesForVariablesFromJit;
    static GlobalSamplingCounter usesWithoutBarrierFromJit;
    
    static void initialize();
    
    static GlobalSamplingCounter& jitCounterFor(WriteBarrierUseKind useKind)
    {
        switch (useKind) {
        case WriteBarrierForPropertyAccess:
            return usesForPropertiesFromJit;
        case WriteBarrierForVariableAccess:
            return usesForVariablesFromJit;
        default:
            ASSERT(useKind == WriteBarrierForGenericAccess);
            return usesWithBarrierFromJit;
        }
    }
#else
    // These are necessary to work around not having conditional exports.
    JS_EXPORTDATA static char usesWithBarrierFromCpp;
    JS_EXPORTDATA static char usesWithoutBarrierFromCpp;
#endif // ENABLE(WRITE_BARRIER_PROFILING)

    static void countWriteBarrier()
    {
#if ENABLE(WRITE_BARRIER_PROFILING)
        WriteBarrierCounters::usesWithBarrierFromCpp.count();
#endif
    }
};

} // namespace JSC

#endif // WriteBarrierSupport_h

