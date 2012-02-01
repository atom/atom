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

#ifndef PutByIdStatus_h
#define PutByIdStatus_h

#include <wtf/NotFound.h>

namespace JSC {

class CodeBlock;
class Identifier;
class Structure;
class StructureChain;

class PutByIdStatus {
public:
    enum State {
        // It's uncached so we have no information.
        NoInformation,
        // It's cached as a direct store into an object property for cases where the object
        // already has the property.
        SimpleReplace,
        // It's cached as a transition from one structure that lacks the property to one that
        // includes the property, and a direct store to this new property.
        SimpleTransition,
        // It's known to often take slow path.
        TakesSlowPath
    };
    
    PutByIdStatus()
        : m_state(NoInformation)
        , m_oldStructure(0)
        , m_newStructure(0)
        , m_structureChain(0)
        , m_offset(notFound)
    {
    }
    
    PutByIdStatus(
        State state,
        Structure* oldStructure,
        Structure* newStructure,
        StructureChain* structureChain,
        size_t offset)
        : m_state(state)
        , m_oldStructure(oldStructure)
        , m_newStructure(newStructure)
        , m_structureChain(structureChain)
        , m_offset(offset)
    {
        ASSERT((m_state == NoInformation || m_state == TakesSlowPath) == !m_oldStructure);
        ASSERT((m_state != SimpleTransition) == !m_newStructure);
        ASSERT((m_state != SimpleTransition) == !m_structureChain);
        ASSERT((m_state == NoInformation || m_state == TakesSlowPath) == (m_offset == notFound));
    }
    
    static PutByIdStatus computeFor(CodeBlock*, unsigned bytecodeIndex, Identifier&);
    
    State state() const { return m_state; }
    
    bool isSet() const { return m_state != NoInformation; }
    bool operator!() const { return m_state == NoInformation; }
    bool isSimpleReplace() const { return m_state == SimpleReplace; }
    bool isSimpleTransition() const { return m_state == SimpleTransition; }
    bool takesSlowPath() const { return m_state == TakesSlowPath; }
    
    Structure* oldStructure() const { return m_oldStructure; }
    Structure* newStructure() const { return m_newStructure; }
    StructureChain* structureChain() const { return m_structureChain; }
    size_t offset() const { return m_offset; }
    
private:
    State m_state;
    Structure* m_oldStructure;
    Structure* m_newStructure;
    StructureChain* m_structureChain;
    size_t m_offset;
};

} // namespace JSC

#endif // PutByIdStatus_h

