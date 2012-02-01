/*
 * Copyright (C) 2008, 2009 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef Structure_h
#define Structure_h

#include "ClassInfo.h"
#include "Identifier.h"
#include "JSCell.h"
#include "JSType.h"
#include "JSValue.h"
#include "PropertyMapHashTable.h"
#include "PropertyNameArray.h"
#include "Protect.h"
#include "StructureTransitionTable.h"
#include "JSTypeInfo.h"
#include "UString.h"
#include "Weak.h"
#include <wtf/PassOwnPtr.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>


namespace JSC {

    class PropertyNameArray;
    class PropertyNameArrayData;
    class StructureChain;
    class SlotVisitor;

    class Structure : public JSCell {
    public:
        friend class StructureTransitionTable;

        typedef JSCell Base;

        static Structure* create(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype, const TypeInfo& typeInfo, const ClassInfo* classInfo)
        {
            ASSERT(globalData.structureStructure);
            ASSERT(classInfo);
            Structure* structure = new (NotNull, allocateCell<Structure>(globalData.heap)) Structure(globalData, globalObject, prototype, typeInfo, classInfo);
            structure->finishCreation(globalData);
            return structure;
        }

    protected:
        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData);
            ASSERT(m_prototype);
            ASSERT(m_prototype.isObject() || m_prototype.isNull());
        }

        void finishCreation(JSGlobalData& globalData, CreatingEarlyCellTag)
        {
            Base::finishCreation(globalData, this, CreatingEarlyCell);
            ASSERT(m_prototype);
            ASSERT(m_prototype.isNull());
            ASSERT(!globalData.structureStructure);
        }

    public:
        static void dumpStatistics();

        JS_EXPORT_PRIVATE static Structure* addPropertyTransition(JSGlobalData&, Structure*, const Identifier& propertyName, unsigned attributes, JSCell* specificValue, size_t& offset);
        JS_EXPORT_PRIVATE static Structure* addPropertyTransitionToExistingStructure(Structure*, const Identifier& propertyName, unsigned attributes, JSCell* specificValue, size_t& offset);
        static Structure* removePropertyTransition(JSGlobalData&, Structure*, const Identifier& propertyName, size_t& offset);
        JS_EXPORT_PRIVATE static Structure* changePrototypeTransition(JSGlobalData&, Structure*, JSValue prototype);
        JS_EXPORT_PRIVATE static Structure* despecifyFunctionTransition(JSGlobalData&, Structure*, const Identifier&);
        static Structure* attributeChangeTransition(JSGlobalData&, Structure*, const Identifier& propertyName, unsigned attributes);
        static Structure* toCacheableDictionaryTransition(JSGlobalData&, Structure*);
        static Structure* toUncacheableDictionaryTransition(JSGlobalData&, Structure*);
        static Structure* sealTransition(JSGlobalData&, Structure*);
        static Structure* freezeTransition(JSGlobalData&, Structure*);
        static Structure* preventExtensionsTransition(JSGlobalData&, Structure*);

        bool isSealed(JSGlobalData&);
        bool isFrozen(JSGlobalData&);
        bool isExtensible() const { return !m_preventExtensions; }
        bool didTransition() const { return m_didTransition; }

        Structure* flattenDictionaryStructure(JSGlobalData&, JSObject*);

        static void destroy(JSCell*);

        // These should be used with caution.  
        JS_EXPORT_PRIVATE size_t addPropertyWithoutTransition(JSGlobalData&, const Identifier& propertyName, unsigned attributes, JSCell* specificValue);
        size_t removePropertyWithoutTransition(JSGlobalData&, const Identifier& propertyName);
        void setPrototypeWithoutTransition(JSGlobalData& globalData, JSValue prototype) { m_prototype.set(globalData, this, prototype); }
        
        bool isDictionary() const { return m_dictionaryKind != NoneDictionaryKind; }
        bool isUncacheableDictionary() const { return m_dictionaryKind == UncachedDictionaryKind; }

        // Type accessors.
        const TypeInfo& typeInfo() const { ASSERT(structure()->classInfo() == &s_info); return m_typeInfo; }
        bool isObject() const { return typeInfo().isObject(); }


        JSGlobalObject* globalObject() const { return m_globalObject.get(); }
        void setGlobalObject(JSGlobalData& globalData, JSGlobalObject* globalObject) { m_globalObject.set(globalData, this, globalObject); }
        
        JSValue storedPrototype() const { return m_prototype.get(); }
        JSValue prototypeForLookup(ExecState*) const;
        StructureChain* prototypeChain(ExecState*) const;
        static void visitChildren(JSCell*, SlotVisitor&);

        Structure* previousID() const { ASSERT(structure()->classInfo() == &s_info); return m_previous.get(); }
        bool transitivelyTransitionedFrom(Structure* structureToFind);

        void growPropertyStorageCapacity();
        unsigned propertyStorageCapacity() const { ASSERT(structure()->classInfo() == &s_info); return m_propertyStorageCapacity; }
        unsigned propertyStorageSize() const { ASSERT(structure()->classInfo() == &s_info); return (m_propertyTable ? m_propertyTable->propertyStorageSize() : static_cast<unsigned>(m_offset + 1)); }
        bool isUsingInlineStorage() const;

        size_t get(JSGlobalData&, const Identifier& propertyName);
        size_t get(JSGlobalData&, const UString& name);
        JS_EXPORT_PRIVATE size_t get(JSGlobalData&, StringImpl* propertyName, unsigned& attributes, JSCell*& specificValue);
        size_t get(JSGlobalData& globalData, const Identifier& propertyName, unsigned& attributes, JSCell*& specificValue)
        {
            ASSERT(!propertyName.isNull());
            ASSERT(structure()->classInfo() == &s_info);
            return get(globalData, propertyName.impl(), attributes, specificValue);
        }

        bool hasGetterSetterProperties() const { return m_hasGetterSetterProperties; }
        void setHasGetterSetterProperties(bool hasGetterSetterProperties) { m_hasGetterSetterProperties = hasGetterSetterProperties; }

        bool hasNonEnumerableProperties() const { return m_hasNonEnumerableProperties; }
        
        bool isEmpty() const { return m_propertyTable ? m_propertyTable->isEmpty() : m_offset == noOffset; }

        JS_EXPORT_PRIVATE void despecifyDictionaryFunction(JSGlobalData&, const Identifier& propertyName);
        void disableSpecificFunctionTracking() { m_specificFunctionThrashCount = maxSpecificFunctionThrashCount; }

        void setEnumerationCache(JSGlobalData&, JSPropertyNameIterator* enumerationCache); // Defined in JSPropertyNameIterator.h.
        JSPropertyNameIterator* enumerationCache(); // Defined in JSPropertyNameIterator.h.
        void getPropertyNamesFromStructure(JSGlobalData&, PropertyNameArray&, EnumerationMode);

        bool staticFunctionsReified()
        {
            return m_staticFunctionReified;
        }

        void setStaticFunctionsReified()
        {
            m_staticFunctionReified = true;
        }

        const ClassInfo* classInfo() const { return m_classInfo; }

        static ptrdiff_t prototypeOffset()
        {
            return OBJECT_OFFSETOF(Structure, m_prototype);
        }

        static ptrdiff_t typeInfoFlagsOffset()
        {
            return OBJECT_OFFSETOF(Structure, m_typeInfo) + TypeInfo::flagsOffset();
        }

        static ptrdiff_t typeInfoTypeOffset()
        {
            return OBJECT_OFFSETOF(Structure, m_typeInfo) + TypeInfo::typeOffset();
        }

        static Structure* createStructure(JSGlobalData& globalData)
        {
            ASSERT(!globalData.structureStructure);
            Structure* structure = new (NotNull, allocateCell<Structure>(globalData.heap)) Structure(globalData);
            structure->finishCreation(globalData, CreatingEarlyCell);
            return structure;
        }
        
        static JS_EXPORTDATA const ClassInfo s_info;

    private:
        JS_EXPORT_PRIVATE Structure(JSGlobalData&, JSGlobalObject*, JSValue prototype, const TypeInfo&, const ClassInfo*);
        Structure(JSGlobalData&);
        Structure(JSGlobalData&, const Structure*);

        static Structure* create(JSGlobalData& globalData, const Structure* structure)
        {
            ASSERT(globalData.structureStructure);
            Structure* newStructure = new (NotNull, allocateCell<Structure>(globalData.heap)) Structure(globalData, structure);
            newStructure->finishCreation(globalData);
            return newStructure;
        }
        
        typedef enum { 
            NoneDictionaryKind = 0,
            CachedDictionaryKind = 1,
            UncachedDictionaryKind = 2
        } DictionaryKind;
        static Structure* toDictionaryTransition(JSGlobalData&, Structure*, DictionaryKind);

        size_t putSpecificValue(JSGlobalData&, const Identifier& propertyName, unsigned attributes, JSCell* specificValue);
        size_t remove(const Identifier& propertyName);

        void createPropertyMap(unsigned keyCount = 0);
        void checkConsistency();

        bool despecifyFunction(JSGlobalData&, const Identifier&);
        void despecifyAllFunctions(JSGlobalData&);

        PassOwnPtr<PropertyTable> copyPropertyTable(JSGlobalData&, Structure* owner);
        PassOwnPtr<PropertyTable> copyPropertyTableForPinning(JSGlobalData&, Structure* owner);
        JS_EXPORT_PRIVATE void materializePropertyMap(JSGlobalData&);
        void materializePropertyMapIfNecessary(JSGlobalData& globalData)
        {
            ASSERT(structure()->classInfo() == &s_info);
            if (!m_propertyTable && m_previous)
                materializePropertyMap(globalData);
        }
        void materializePropertyMapIfNecessaryForPinning(JSGlobalData& globalData)
        {
            ASSERT(structure()->classInfo() == &s_info);
            if (!m_propertyTable)
                materializePropertyMap(globalData);
        }

        int transitionCount() const
        {
            // Since the number of transitions is always the same as m_offset, we keep the size of Structure down by not storing both.
            return m_offset == noOffset ? 0 : m_offset + 1;
        }

        bool isValid(ExecState*, StructureChain* cachedPrototypeChain) const;
        
        void pin();

        static const int s_maxTransitionLength = 64;

        static const int noOffset = -1;

        static const unsigned maxSpecificFunctionThrashCount = 3;

        TypeInfo m_typeInfo;
        
        WriteBarrier<JSGlobalObject> m_globalObject;
        WriteBarrier<Unknown> m_prototype;
        mutable WriteBarrier<StructureChain> m_cachedPrototypeChain;

        WriteBarrier<Structure> m_previous;
        RefPtr<StringImpl> m_nameInPrevious;
        WriteBarrier<JSCell> m_specificValueInPrevious;

        const ClassInfo* m_classInfo;

        StructureTransitionTable m_transitionTable;

        WriteBarrier<JSPropertyNameIterator> m_enumerationCache;

        OwnPtr<PropertyTable> m_propertyTable;

        uint32_t m_propertyStorageCapacity;

        // m_offset does not account for anonymous slots
        int m_offset;

        unsigned m_dictionaryKind : 2;
        bool m_isPinnedPropertyTable : 1;
        bool m_hasGetterSetterProperties : 1;
        bool m_hasNonEnumerableProperties : 1;
        unsigned m_attributesInPrevious : 7;
        unsigned m_specificFunctionThrashCount : 2;
        unsigned m_preventExtensions : 1;
        unsigned m_didTransition : 1;
        unsigned m_staticFunctionReified;
    };

    inline size_t Structure::get(JSGlobalData& globalData, const Identifier& propertyName)
    {
        ASSERT(structure()->classInfo() == &s_info);
        materializePropertyMapIfNecessary(globalData);
        if (!m_propertyTable)
            return notFound;

        PropertyMapEntry* entry = m_propertyTable->find(propertyName.impl()).first;
        return entry ? entry->offset : notFound;
    }

    inline size_t Structure::get(JSGlobalData& globalData, const UString& name)
    {
        ASSERT(structure()->classInfo() == &s_info);
        materializePropertyMapIfNecessary(globalData);
        if (!m_propertyTable)
            return notFound;

        PropertyMapEntry* entry = m_propertyTable->findWithString(name.impl()).first;
        return entry ? entry->offset : notFound;
    }
    
    inline bool JSCell::isObject() const
    {
        return m_structure->isObject();
    }

    inline bool JSCell::isString() const
    {
        return m_structure->typeInfo().type() == StringType;
    }

    inline bool JSCell::isGetterSetter() const
    {
        return m_structure->typeInfo().type() == GetterSetterType;
    }

    inline bool JSCell::isAPIValueWrapper() const
    {
        return m_structure->typeInfo().type() == APIValueWrapperType;
    }

    inline void JSCell::setStructure(JSGlobalData& globalData, Structure* structure)
    {
        ASSERT(structure->typeInfo().overridesVisitChildren() == this->structure()->typeInfo().overridesVisitChildren());
        ASSERT(structure->classInfo() == m_structure->classInfo());
        m_structure.set(globalData, this, structure);
    }

    inline const ClassInfo* JSCell::validatedClassInfo() const
    {
#if ENABLE(GC_VALIDATION)
        ASSERT(m_structure.unvalidatedGet()->classInfo() == m_classInfo);
#else
        ASSERT(m_structure->classInfo() == m_classInfo);
#endif
        return m_classInfo;
    }

    ALWAYS_INLINE void MarkStack::internalAppend(JSCell* cell)
    {
        ASSERT(!m_isCheckingForDefaultMarkViolation);
#if ENABLE(GC_VALIDATION)
        validate(cell);
#endif
        m_visitCount++;
        if (Heap::testAndSetMarked(cell) || !cell->structure())
            return;
        
        // Should never attempt to mark something that is zapped.
        ASSERT(!cell->isZapped());
        
        m_stack.append(cell);
    }

    inline StructureTransitionTable::Hash::Key StructureTransitionTable::keyForWeakGCMapFinalizer(void*, Structure* structure)
    {
        // Newer versions of the STL have an std::make_pair function that takes rvalue references.
        // When either of the parameters are bitfields, the C++ compiler will try to bind them as lvalues, which is invalid. To work around this, use unary "+" to make the parameter an rvalue.
        // See https://bugs.webkit.org/show_bug.cgi?id=59261 for more details.
        return Hash::Key(structure->m_nameInPrevious.get(), +structure->m_attributesInPrevious);
    }

    inline bool Structure::transitivelyTransitionedFrom(Structure* structureToFind)
    {
        for (Structure* current = this; current; current = current->previousID()) {
            if (current == structureToFind)
                return true;
        }
        return false;
    }

    inline JSCell::JSCell(JSGlobalData& globalData, Structure* structure)
        : m_classInfo(structure->classInfo())
        , m_structure(globalData, this, structure)
    {
    }

    inline void JSCell::finishCreation(JSGlobalData& globalData, Structure* structure, CreatingEarlyCellTag)
    {
#if ENABLE(GC_VALIDATION)
        ASSERT(globalData.isInitializingObject());
        globalData.setInitializingObject(false);
        if (structure)
#endif
            m_structure.setEarlyValue(globalData, this, structure);
        m_classInfo = structure->classInfo();
        // Very first set of allocations won't have a real structure.
        ASSERT(m_structure || !globalData.structureStructure);
    }

} // namespace JSC

#endif // Structure_h
