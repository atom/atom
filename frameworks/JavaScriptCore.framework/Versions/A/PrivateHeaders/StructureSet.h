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

#ifndef StructureSet_h
#define StructureSet_h

#include "PredictedType.h"
#include <stdio.h>
#include <wtf/Vector.h>

namespace JSC {

class Structure;

namespace DFG {
class StructureAbstractValue;
}

class StructureSet {
public:
    StructureSet() { }
    
    StructureSet(Structure* structure)
    {
        m_structures.append(structure);
    }
    
    void clear()
    {
        m_structures.clear();
    }
    
    void add(Structure* structure)
    {
        ASSERT(!contains(structure));
        m_structures.append(structure);
    }
    
    bool addAll(const StructureSet& other)
    {
        bool changed = false;
        for (size_t i = 0; i < other.size(); ++i) {
            if (contains(other[i]))
                continue;
            add(other[i]);
            changed = true;
        }
        return changed;
    }
    
    void remove(Structure* structure)
    {
        for (size_t i = 0; i < m_structures.size(); ++i) {
            if (m_structures[i] != structure)
                continue;
            
            m_structures[i] = m_structures.last();
            m_structures.removeLast();
            return;
        }
    }
    
    bool contains(Structure* structure) const
    {
        for (size_t i = 0; i < m_structures.size(); ++i) {
            if (m_structures[i] == structure)
                return true;
        }
        return false;
    }
    
    bool isSubsetOf(const StructureSet& other) const
    {
        for (size_t i = 0; i < m_structures.size(); ++i) {
            if (!other.contains(m_structures[i]))
                return false;
        }
        return true;
    }
    
    bool isSupersetOf(const StructureSet& other) const
    {
        return other.isSubsetOf(*this);
    }
    
    size_t size() const { return m_structures.size(); }
    
    Structure* at(size_t i) const { return m_structures.at(i); }
    
    Structure* operator[](size_t i) const { return at(i); }
    
    Structure* last() const { return m_structures.last(); }

    PredictedType predictionFromStructures() const
    {
        PredictedType result = PredictNone;
        
        for (size_t i = 0; i < m_structures.size(); ++i)
            mergePrediction(result, predictionFromStructure(m_structures[i]));
        
        return result;
    }
    
    bool operator==(const StructureSet& other) const
    {
        if (m_structures.size() != other.m_structures.size())
            return false;
        
        for (size_t i = 0; i < m_structures.size(); ++i) {
            if (!other.contains(m_structures[i]))
                return false;
        }
        
        return true;
    }
    
    void dump(FILE* out)
    {
        fprintf(out, "[");
        for (size_t i = 0; i < m_structures.size(); ++i) {
            if (i)
                fprintf(out, ", ");
            fprintf(out, "%p", m_structures[i]);
        }
        fprintf(out, "]");
    }
    
private:
    friend class DFG::StructureAbstractValue;
    
    Vector<Structure*, 2> m_structures;
};

} // namespace JSC

#endif // StructureSet_h
