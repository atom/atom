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

#ifndef DFGAbstractValue_h
#define DFGAbstractValue_h

#include <wtf/Platform.h>

#if ENABLE(DFG_JIT)

#include "JSCell.h"
#include "PredictedType.h"
#include "StructureSet.h"

namespace JSC { namespace DFG {

class StructureAbstractValue {
public:
    StructureAbstractValue()
        : m_structure(0)
    {
    }
    
    StructureAbstractValue(Structure* structure)
        : m_structure(structure)
    {
    }
    
    StructureAbstractValue(const StructureSet& set)
    {
        switch (set.size()) {
        case 0:
            m_structure = 0;
            break;
            
        case 1:
            m_structure = set[0];
            break;
            
        default:
            m_structure = topValue();
            break;
        }
    }
    
    void clear()
    {
        m_structure = 0;
    }
    
    void makeTop()
    {
        m_structure = topValue();
    }
    
    static StructureAbstractValue top()
    {
        StructureAbstractValue value;
        value.makeTop();
        return value;
    }
    
    void add(Structure* structure)
    {
        ASSERT(!contains(structure) && !isTop());
        if (m_structure)
            makeTop();
        else
            m_structure = structure;
    }
    
    bool addAll(const StructureSet& other)
    {
        if (isTop() || !other.size())
            return false;
        if (other.size() > 1) {
            makeTop();
            return true;
        }
        if (!m_structure) {
            m_structure = other[0];
            return true;
        }
        if (m_structure == other[0])
            return false;
        makeTop();
        return true;
    }
    
    bool addAll(const StructureAbstractValue& other)
    {
        if (!other.m_structure)
            return false;
        if (isTop())
            return false;
        if (other.isTop()) {
            makeTop();
            return true;
        }
        if (m_structure) {
            if (m_structure == other.m_structure)
                return false;
            makeTop();
            return true;
        }
        m_structure = other.m_structure;
        return true;
    }
    
    bool contains(Structure* structure) const
    {
        if (isTop())
            return true;
        if (m_structure == structure)
            return true;
        return false;
    }
    
    bool isSubsetOf(const StructureSet& other) const
    {
        if (isTop())
            return false;
        if (!m_structure)
            return true;
        return other.contains(m_structure);
    }
    
    bool doesNotContainAnyOtherThan(Structure* structure) const
    {
        if (isTop())
            return false;
        if (!m_structure)
            return true;
        return m_structure == structure;
    }
    
    bool isSupersetOf(const StructureSet& other) const
    {
        if (isTop())
            return true;
        if (!other.size())
            return true;
        if (other.size() > 1)
            return false;
        return m_structure == other[0];
    }
    
    bool isSubsetOf(const StructureAbstractValue& other) const
    {
        if (other.isTop())
            return true;
        if (isTop())
            return false;
        if (m_structure) {
            if (other.m_structure)
                return m_structure == other.m_structure;
            return false;
        }
        return true;
    }
    
    bool isSupersetOf(const StructureAbstractValue& other) const
    {
        return other.isSubsetOf(*this);
    }
    
    void filter(const StructureSet& other)
    {
        if (!m_structure)
            return;
        
        if (isTop()) {
            switch (other.size()) {
            case 0:
                m_structure = 0;
                return;
                
            case 1:
                m_structure = other[0];
                return;
                
            default:
                return;
            }
        }
        
        if (other.contains(m_structure))
            return;
        
        m_structure = 0;
    }
    
    void filter(const StructureAbstractValue& other)
    {
        if (isTop()) {
            m_structure = other.m_structure;
            return;
        }
        if (m_structure == other.m_structure)
            return;
        if (other.isTop())
            return;
        m_structure = 0;
    }
    
    void filter(PredictedType other)
    {
        if (!(other & PredictCell)) {
            clear();
            return;
        }
        
        if (isClearOrTop())
            return;

        if (!(predictionFromStructure(m_structure) & other))
            m_structure = 0;
    }
    
    bool isClear() const
    {
        return !m_structure;
    }
    
    bool isTop() const { return m_structure == topValue(); }
    
    bool isClearOrTop() const { return m_structure <= topValue(); }
    bool isNeitherClearNorTop() const { return !isClearOrTop(); }
    
    size_t size() const
    {
        ASSERT(!isTop());
        return !!m_structure;
    }
    
    Structure* at(size_t i) const
    {
        ASSERT(!isTop());
        ASSERT(m_structure);
        ASSERT_UNUSED(i, !i);
        return m_structure;
    }
    
    Structure* operator[](size_t i) const
    {
        return at(i);
    }
    
    Structure* last() const
    {
        return at(0);
    }
    
    PredictedType predictionFromStructures() const
    {
        if (isTop())
            return PredictCell;
        if (isClear())
            return PredictNone;
        return predictionFromStructure(m_structure);
    }
    
    bool operator==(const StructureAbstractValue& other) const
    {
        return m_structure == other.m_structure;
    }
    
#ifndef NDEBUG
    void dump(FILE* out) const
    {
        if (isTop()) {
            fprintf(out, "TOP");
            return;
        }
        
        fprintf(out, "[");
        if (m_structure)
            fprintf(out, "%p", m_structure);
        fprintf(out, "]");
    }
#endif

private:
    static Structure* topValue() { return reinterpret_cast<Structure*>(1); }
    
    // This can only remember one structure at a time.
    Structure* m_structure;
};

struct AbstractValue {
    AbstractValue()
        : m_type(PredictNone)
    {
    }
    
    void clear()
    {
        m_type = PredictNone;
        m_structure.clear();
        checkConsistency();
    }
    
    bool isClear()
    {
        return m_type == PredictNone && m_structure.isClear();
    }
    
    void makeTop()
    {
        m_type = PredictTop;
        m_structure.makeTop();
        checkConsistency();
    }
    
    void clobberStructures()
    {
        if (m_type & PredictCell)
            m_structure.makeTop();
        else
            ASSERT(m_structure.isClear());
        checkConsistency();
    }
    
    bool isTop() const
    {
        return m_type == PredictTop && m_structure.isTop();
    }
    
    static AbstractValue top()
    {
        AbstractValue result;
        result.makeTop();
        return result;
    }
    
    void set(JSValue value)
    {
        m_structure.clear();
        if (value.isCell())
            m_structure.add(value.asCell()->structure());
        
        m_type = predictionFromValue(value);
        
        checkConsistency();
    }
    
    void set(Structure* structure)
    {
        m_structure.clear();
        m_structure.add(structure);
        
        m_type = predictionFromStructure(structure);
        
        checkConsistency();
    }
    
    void set(PredictedType type)
    {
        if (type & PredictCell)
            m_structure.makeTop();
        else
            m_structure.clear();
        m_type = type;
        checkConsistency();
    }
    
    bool operator==(const AbstractValue& other) const
    {
        return m_type == other.m_type && m_structure == other.m_structure;
    }
    
    bool merge(const AbstractValue& other)
    {
        bool result = mergePrediction(m_type, other.m_type) | m_structure.addAll(other.m_structure);
        checkConsistency();
        return result;
    }
    
    void merge(PredictedType type)
    {
        mergePrediction(m_type, type);
        
        if (type & PredictCell)
            m_structure.makeTop();

        checkConsistency();
    }
    
    void filter(const StructureSet& other)
    {
        m_type &= other.predictionFromStructures();
        m_structure.filter(other);
        
        // It's possible that prior to the above two statements we had (Foo, TOP), where
        // Foo is a PredictedType that is disjoint with the passed StructureSet. In that
        // case, we will now have (None, [someStructure]). In general, we need to make
        // sure that new information gleaned from the PredictedType needs to be fed back
        // into the information gleaned from the StructureSet.
        m_structure.filter(m_type);
        checkConsistency();
    }
    
    void filter(PredictedType type)
    {
        if (type == PredictTop)
            return;
        m_type &= type;
        
        // It's possible that prior to this filter() call we had, say, (Final, TOP), and
        // the passed type is Array. At this point we'll have (None, TOP). The best way
        // to ensure that the structure filtering does the right thing is to filter on
        // the new type (None) rather than the one passed (Array).
        m_structure.filter(m_type);
        checkConsistency();
    }
    
    bool validate(JSValue value) const
    {
        if (isTop())
            return true;
        
        if (mergePredictions(m_type, predictionFromValue(value)) != m_type)
            return false;
        
        if (m_structure.isTop())
            return true;
        
        if (value.isCell()) {
            ASSERT(m_type & PredictCell);
            return m_structure.contains(value.asCell()->structure());
        }
        
        return true;
    }
    
    void checkConsistency() const
    {
        if (!(m_type & PredictCell))
            ASSERT(m_structure.isClear());
        
        // Note that it's possible for a prediction like (Final, []). This really means that
        // the value is bottom and that any code that uses the value is unreachable. But
        // we don't want to get pedantic about this as it would only increase the computational
        // complexity of the code.
    }
    
#ifndef NDEBUG
    void dump(FILE* out) const
    {
        fprintf(out, "(%s, ", predictionToString(m_type));
        m_structure.dump(out);
        fprintf(out, ")");
    }
#endif

    StructureAbstractValue m_structure;
    PredictedType m_type;
};

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGAbstractValue_h


