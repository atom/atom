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

#ifndef DFGCommon_h
#define DFGCommon_h

#include <wtf/Platform.h>

#if ENABLE(DFG_JIT)

#include "CodeOrigin.h"
#include "VirtualRegister.h"

/* DFG_ENABLE() - turn on a specific features in the DFG JIT */
#define DFG_ENABLE(DFG_FEATURE) (defined DFG_ENABLE_##DFG_FEATURE && DFG_ENABLE_##DFG_FEATURE)

// Emit various logging information for debugging, including dumping the dataflow graphs.
#define DFG_ENABLE_DEBUG_VERBOSE 0
// Emit dumps during propagation, in addition to just after.
#define DFG_ENABLE_DEBUG_PROPAGATION_VERBOSE 0
// Emit logging for OSR exit value recoveries at every node, not just nodes that
// actually has speculation checks.
#define DFG_ENABLE_VERBOSE_VALUE_RECOVERIES 0
// Enable generation of dynamic checks into the instruction stream.
#if !ASSERT_DISABLED
#define DFG_ENABLE_JIT_ASSERT 1
#else
#define DFG_ENABLE_JIT_ASSERT 0
#endif
// Consistency check contents compiler data structures.
#define DFG_ENABLE_CONSISTENCY_CHECK 0
// Emit a breakpoint into the head of every generated function, to aid debugging in GDB.
#define DFG_ENABLE_JIT_BREAK_ON_EVERY_FUNCTION 0
// Emit a breakpoint into the head of every generated node, to aid debugging in GDB.
#define DFG_ENABLE_JIT_BREAK_ON_EVERY_BLOCK 0
// Emit a breakpoint into the head of every generated node, to aid debugging in GDB.
#define DFG_ENABLE_JIT_BREAK_ON_EVERY_NODE 0
// Emit a pair of xorPtr()'s on regT0 with the node index to make it easy to spot node boundaries in disassembled code.
#define DFG_ENABLE_XOR_DEBUG_AID 0
// Emit a breakpoint into the speculation failure code.
#define DFG_ENABLE_JIT_BREAK_ON_SPECULATION_FAILURE 0
// Log every speculation failure.
#define DFG_ENABLE_VERBOSE_SPECULATION_FAILURE 0
// Disable the DFG JIT without having to touch Platform.h
#define DFG_DEBUG_LOCAL_DISBALE 0
// Enable OSR entry from baseline JIT.
#define DFG_ENABLE_OSR_ENTRY ENABLE(DFG_JIT)
// Generate stats on how successful we were in making use of the DFG jit, and remaining on the hot path.
#define DFG_ENABLE_SUCCESS_STATS 0
// Used to enable conditionally supported opcodes that currently result in performance regressions.
#define DFG_ENABLE_RESTRICTIONS 1

namespace JSC { namespace DFG {

// Type for a reference to another node in the graph.
typedef uint32_t NodeIndex;
static const NodeIndex NoNode = UINT_MAX;

typedef uint32_t BlockIndex;
static const BlockIndex NoBlock = UINT_MAX;

struct NodeIndexTraits {
    static NodeIndex defaultValue() { return NoNode; }
    static void dump(NodeIndex value, FILE* out)
    {
        if (value == NoNode)
            fprintf(out, "-");
        else
            fprintf(out, "@%u", value);
    }
};

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGCommon_h

