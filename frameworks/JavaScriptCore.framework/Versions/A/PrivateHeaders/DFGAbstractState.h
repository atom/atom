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

#ifndef DFGAbstractState_h
#define DFGAbstractState_h

#include <wtf/Platform.h>

#if ENABLE(DFG_JIT)

#include "DFGAbstractValue.h"
#include "DFGGraph.h"
#include "DFGNode.h"
#include <wtf/Vector.h>

namespace JSC {

class CodeBlock;

namespace DFG {

struct BasicBlock;

// This implements the notion of an abstract state for flow-sensitive intraprocedural
// control flow analysis (CFA), with a focus on the elimination of redundant type checks.
// It also implements most of the mechanisms of abstract interpretation that such an
// analysis would use. This class should be used in two idioms:
//
// 1) Performing the CFA. In this case, AbstractState should be run over all basic
//    blocks repeatedly until convergence is reached. Convergence is defined by
//    endBasicBlock(AbstractState::MergeToSuccessors) returning false for all blocks.
//
// 2) Rematerializing the results of a previously executed CFA. In this case,
//    AbstractState should be run over whatever basic block you're interested in up
//    to the point of the node at which you'd like to interrogate the known type
//    of all other nodes. At this point it's safe to discard the AbstractState entirely,
//    call reset(), or to run it to the end of the basic block and call
//    endBasicBlock(AbstractState::DontMerge). The latter option is safest because
//    it performs some useful integrity checks.
//
// After the CFA is run, the inter-block state is saved at the heads and tails of all
// basic blocks. This allows the intra-block state to be rematerialized by just
// executing the CFA for that block. If you need to know inter-block state only, then
// you only need to examine the BasicBlock::m_valuesAtHead or m_valuesAtTail fields.
//
// Running this analysis involves the following, modulo the inter-block state
// merging and convergence fixpoint:
//
// AbstractState state(codeBlock, graph);
// state.beginBasicBlock(basicBlock);
// bool endReached = true;
// for (NodeIndex idx = basicBlock.begin; idx < basicBlock.end; ++idx) {
//     if (!state.execute(idx))
//         break;
// }
// bool result = state.endBasicBlock(<either Merge or DontMerge>);

class AbstractState {
public:
    enum MergeMode {
        // Don't merge the state in AbstractState with basic blocks.
        DontMerge,
        
        // Merge the state in AbstractState with the tail of the basic
        // block being analyzed.
        MergeToTail,
        
        // Merge the state in AbstractState with the tail of the basic
        // block, and with the heads of successor blocks.
        MergeToSuccessors
    };
    
    AbstractState(CodeBlock*, Graph&);
    
    ~AbstractState();
    
    AbstractValue& forNode(NodeIndex nodeIndex)
    {
        return m_nodes[nodeIndex - m_block->begin];
    }
    
    // Call this before beginning CFA to initialize the abstract values of
    // arguments, and to indicate which blocks should be listed for CFA
    // execution.
    static void initialize(Graph&);

    // Start abstractly executing the given basic block. Initializes the
    // notion of abstract state to what we believe it to be at the head
    // of the basic block, according to the basic block's data structures.
    // This method also sets cfaShouldRevisit to false.
    void beginBasicBlock(BasicBlock*);
    
    // Finish abstractly executing a basic block. If MergeToTail or
    // MergeToSuccessors is passed, then this merges everything we have
    // learned about how the state changes during this block's execution into
    // the block's data structures. There are three return modes, depending
    // on the value of mergeMode:
    //
    // DontMerge:
    //    Always returns false.
    //
    // MergeToTail:
    //    Returns true if the state of the block at the tail was changed.
    //    This means that you must call mergeToSuccessors(), and if that
    //    returns true, then you must revisit (at least) the successor
    //    blocks. False will always be returned if the block is terminal
    //    (i.e. ends in Throw or Return, or has a ForceOSRExit inside it).
    //
    // MergeToSuccessors:
    //    Returns true if the state of the block at the tail was changed,
    //    and, if the state at the heads of successors was changed.
    //    A true return means that you must revisit (at least) the successor
    //    blocks. This also sets cfaShouldRevisit to true for basic blocks
    //    that must be visited next.
    bool endBasicBlock(MergeMode);
    
    // Reset the AbstractState. This throws away any results, and at this point
    // you can safely call beginBasicBlock() on any basic block.
    void reset();
    
    // Abstractly executes the given node. The new abstract state is stored into an
    // abstract register file stored in *this. Loads of local variables (that span
    // basic blocks) interrogate the basic block's notion of the state at the head.
    // Stores to local variables are handled in endBasicBlock(). This returns true
    // if execution should continue past this node. Notably, it will return true
    // for block terminals, so long as those terminals are not Return or variants
    // of Throw.
    bool execute(NodeIndex);
    
    // Is the execution state still valid? This will be false if execute() has
    // returned false previously.
    bool isValid() const { return m_isValid; }
    
    // Merge the abstract state stored at the first block's tail into the second
    // block's head. Returns true if the second block's state changed. If so,
    // that block must be abstractly interpreted again. This also sets
    // to->cfaShouldRevisit to true, if it returns true, or if to has not been
    // visited yet.
    static bool merge(BasicBlock* from, BasicBlock* to);
    
    // Merge the abstract state stored at the block's tail into all of its
    // successors. Returns true if any of the successors' states changed. Note
    // that this is automatically called in endBasicBlock() if MergeMode is
    // MergeToSuccessors.
    static bool mergeToSuccessors(Graph&, BasicBlock*);

#ifndef NDEBUG
    void dump(FILE* out);
#endif
    
private:
    void clobberStructures(NodeIndex);
    
    bool mergeStateAtTail(AbstractValue& destination, AbstractValue& inVariable, NodeIndex);
    
    static bool mergeVariableBetweenBlocks(AbstractValue& destination, AbstractValue& source, NodeIndex destinationNodeIndex, NodeIndex sourceNodeIndex);
    
    CodeBlock* m_codeBlock;
    Graph& m_graph;
    
    Vector<AbstractValue, 32> m_nodes;
    Operands<AbstractValue> m_variables;
    BasicBlock* m_block;
    bool m_haveStructures;
    
    bool m_isValid;
};

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGAbstractState_h

