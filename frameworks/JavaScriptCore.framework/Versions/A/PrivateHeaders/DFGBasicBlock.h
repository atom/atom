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

#ifndef DFGBasicBlock_h
#define DFGBasicBlock_h

#if ENABLE(DFG_JIT)

#include "DFGAbstractValue.h"
#include "DFGNode.h"
#include "DFGOperands.h"
#include <wtf/OwnPtr.h>
#include <wtf/Vector.h>

namespace JSC { namespace DFG {

typedef Vector <BlockIndex, 2> PredecessorList;

struct BasicBlock {
    BasicBlock(unsigned bytecodeBegin, NodeIndex begin, unsigned numArguments, unsigned numLocals)
        : bytecodeBegin(bytecodeBegin)
        , begin(begin)
        , end(NoNode)
        , isOSRTarget(false)
        , cfaHasVisited(false)
        , cfaShouldRevisit(false)
#if !ASSERT_DISABLED
        , isLinked(false)
#endif
        , isReachable(false)
        , variablesAtHead(numArguments, numLocals)
        , variablesAtTail(numArguments, numLocals)
        , valuesAtHead(numArguments, numLocals)
        , valuesAtTail(numArguments, numLocals)
    {
    }
    
    void ensureLocals(unsigned newNumLocals)
    {
        variablesAtHead.ensureLocals(newNumLocals);
        variablesAtTail.ensureLocals(newNumLocals);
        valuesAtHead.ensureLocals(newNumLocals);
        valuesAtTail.ensureLocals(newNumLocals);
    }

    // This value is used internally for block linking and OSR entry. It is mostly meaningless
    // for other purposes due to inlining.
    unsigned bytecodeBegin;
    
    NodeIndex begin;
    NodeIndex end;
    bool isOSRTarget;
    bool cfaHasVisited;
    bool cfaShouldRevisit;
#if !ASSERT_DISABLED
    bool isLinked;
#endif
    bool isReachable;
    
    PredecessorList m_predecessors;
    
    Operands<NodeIndex, NodeIndexTraits> variablesAtHead;
    Operands<NodeIndex, NodeIndexTraits> variablesAtTail;
    
    Operands<AbstractValue> valuesAtHead;
    Operands<AbstractValue> valuesAtTail;
};

struct UnlinkedBlock {
    BlockIndex m_blockIndex;
    bool m_needsNormalLinking;
    bool m_needsEarlyReturnLinking;
    
    UnlinkedBlock() { }
    
    explicit UnlinkedBlock(BlockIndex blockIndex)
        : m_blockIndex(blockIndex)
        , m_needsNormalLinking(true)
        , m_needsEarlyReturnLinking(false)
    {
    }
};
    
} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGBasicBlock_h

