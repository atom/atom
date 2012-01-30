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

#ifndef GetByIdStatus_h
#define GetByIdStatus_h

#include "StructureSet.h"
#include <wtf/NotFound.h>

namespace JSC {

class CodeBlock;
class Identifier;

class GetByIdStatus {
public:
    enum State {
        NoInformation,  // It's uncached so we have no information.
        SimpleDirect,   // It's cached for a direct access to a known object property.
        TakesSlowPath,  // It's known to often take slow path.
        MakesCalls      // It's known to take paths that make calls.
    };

    GetByIdStatus()
        : m_state(NoInformation)
        , m_offset(notFound)
    {
    }
    
    GetByIdStatus(State state, const StructureSet& structureSet, size_t offset)
        : m_state(state)
        , m_structureSet(structureSet)
        , m_offset(offset)
    {
        ASSERT((state == SimpleDirect) == (offset != notFound));
    }
    
    static GetByIdStatus computeFor(CodeBlock*, unsigned bytecodeIndex, Identifier&);
    
    State state() const { return m_state; }
    
    bool isSet() const { return m_state != NoInformation; }
    bool operator!() const { return !isSet(); }
    bool isSimpleDirect() const { return m_state == SimpleDirect; }
    bool takesSlowPath() const { return m_state == TakesSlowPath || m_state == MakesCalls; }
    bool makesCalls() const { return m_state == MakesCalls; }
    
    const StructureSet& structureSet() const { return m_structureSet; }
    size_t offset() const { return m_offset; }
    
private:
    State m_state;
    StructureSet m_structureSet;
    size_t m_offset;
};

} // namespace JSC

#endif // PropertyAccessStatus_h

