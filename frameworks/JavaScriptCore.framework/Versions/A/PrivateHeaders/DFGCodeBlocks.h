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

#ifndef DFGCodeBlocks_h
#define DFGCodeBlocks_h

#include <wtf/FastAllocBase.h>
#include <wtf/HashSet.h>
#include <wtf/PassOwnPtr.h>

namespace JSC {

class CodeBlock;
class SlotVisitor;

// DFGCodeBlocks notifies the garbage collector about optimized code blocks that
// have different marking behavior depending on whether or not they are on the
// stack, and that may be jettisoned. Jettisoning is the process of discarding
// a code block after all calls to it have been unlinked. This class takes special
// care to ensure that if there are still call frames that are using the code
// block, then it should not be immediately deleted, but rather, it should be
// deleted once we know that there are no longer any references to it from any
// call frames. This class takes its name from the DFG compiler; only code blocks
// compiled by the DFG need special marking behavior if they are on the stack, and
// only those code blocks may be jettisoned.

#if ENABLE(DFG_JIT)
class DFGCodeBlocks {
    WTF_MAKE_FAST_ALLOCATED;

public:
    DFGCodeBlocks();
    ~DFGCodeBlocks();
    
    // Inform the collector that a code block has been jettisoned form its
    // executable and should only be kept alive if there are call frames that use
    // it. This is typically called either from a recompilation trigger, or from
    // an unconditional finalizer associated with a CodeBlock that had weak
    // references, where some subset of those references were dead.
    void jettison(PassOwnPtr<CodeBlock>);
    
    // Clear all mark bits associated with DFG code blocks.
    void clearMarks();
    
    // Mark a pointer that may be a CodeBlock that belongs to the set of DFG code
    // blocks. This is defined inline in CodeBlock.h
    void mark(void* candidateCodeBlock);
    
    // Delete all jettisoned code blocks that have not been marked (i.e. are not referenced
    // from call frames).
    void deleteUnmarkedJettisonedCodeBlocks();
    
    // Trace all marked code blocks (i.e. are referenced from call frames). The CodeBlock
    // is free to make use of m_dfgData->isMarked and m_dfgData->isJettisoned.
    void traceMarkedCodeBlocks(SlotVisitor&);

private:
    friend class CodeBlock;
    
    HashSet<CodeBlock*> m_set;
};
#else
class DFGCodeBlocks {
    WTF_MAKE_FAST_ALLOCATED;

public:
    void jettison(PassOwnPtr<CodeBlock>);
    void clearMarks() { }
    void mark(void*) { }
    void deleteUnmarkedJettisonedCodeBlocks() { }
    void traceMarkedCodeBlocks(SlotVisitor&) { }
};
#endif

} // namespace JSC

#endif
