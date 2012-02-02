/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2003, 2007, 2008, 2009 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#ifndef JSArray_h
#define JSArray_h

#include "JSObject.h"

#define CHECK_ARRAY_CONSISTENCY 0

namespace JSC {

    class JSArray;

    struct SparseArrayEntry : public WriteBarrier<Unknown> {
        typedef WriteBarrier<Unknown> Base;

        SparseArrayEntry() : attributes(0) {}

        JSValue get(ExecState*, JSArray*) const;
        void get(PropertySlot&) const;
        void get(PropertyDescriptor&) const;
        JSValue getNonSparseMode() const;

        unsigned attributes;
    };

    class SparseArrayValueMap {
        typedef HashMap<uint64_t, SparseArrayEntry, WTF::IntHash<uint64_t>, WTF::UnsignedWithZeroKeyHashTraits<uint64_t> > Map;

        enum Flags {
            Normal = 0,
            SparseMode = 1,
            LengthIsReadOnly = 2,
        };

    public:
        typedef Map::iterator iterator;
        typedef Map::const_iterator const_iterator;

        SparseArrayValueMap()
            : m_flags(Normal)
            , m_reportedCapacity(0)
        {
        }

        void visitChildren(SlotVisitor&);

        bool sparseMode()
        {
            return m_flags & SparseMode;
        }

        void setSparseMode()
        {
            m_flags = static_cast<Flags>(m_flags | SparseMode);
        }

        bool lengthIsReadOnly()
        {
            return m_flags & LengthIsReadOnly;
        }

        void setLengthIsReadOnly()
        {
            m_flags = static_cast<Flags>(m_flags | LengthIsReadOnly);
        }

        // These methods may mutate the contents of the map
        void put(ExecState*, JSArray*, unsigned, JSValue);
        std::pair<iterator, bool> add(JSArray*, unsigned);
        iterator find(unsigned i) { return m_map.find(i); }
        // This should ASSERT the remove is valid (check the result of the find).
        void remove(iterator it) { m_map.remove(it); }
        void remove(unsigned i) { m_map.remove(i); }

        // These methods do not mutate the contents of the map.
        iterator notFound() { return m_map.end(); }
        bool isEmpty() const { return m_map.isEmpty(); }
        bool contains(unsigned i) const { return m_map.contains(i); }
        size_t size() const { return m_map.size(); }
        // Only allow const begin/end iteration.
        const_iterator begin() const { return m_map.begin(); }
        const_iterator end() const { return m_map.end(); }

    private:
        Map m_map;
        Flags m_flags;
        size_t m_reportedCapacity;
    };

    // This struct holds the actual data values of an array.  A JSArray object points to it's contained ArrayStorage
    // struct by pointing to m_vector.  To access the contained ArrayStorage struct, use the getStorage() and 
    // setStorage() methods.  It is important to note that there may be space before the ArrayStorage that 
    // is used to quick unshift / shift operation.  The actual allocated pointer is available by using:
    //     getStorage() - m_indexBias * sizeof(JSValue)
    struct ArrayStorage {
        unsigned m_length; // The "length" property on the array
        unsigned m_numValuesInVector;
        void* m_allocBase; // Pointer to base address returned by malloc().  Keeping this pointer does eliminate false positives from the leak detector.
#if CHECK_ARRAY_CONSISTENCY
        bool m_inCompactInitialization;
#endif
        WriteBarrier<Unknown> m_vector[1];
    };

    class JSArray : public JSNonFinalObject {
        friend class Walker;

    protected:
        JS_EXPORT_PRIVATE explicit JSArray(JSGlobalData&, Structure*);

        JS_EXPORT_PRIVATE void finishCreation(JSGlobalData&, unsigned initialLength = 0);
        JS_EXPORT_PRIVATE JSArray* tryFinishCreationUninitialized(JSGlobalData&, unsigned initialLength);
    
    public:
        typedef JSNonFinalObject Base;

        JS_EXPORT_PRIVATE ~JSArray();
        JS_EXPORT_PRIVATE static void destroy(JSCell*);

        static JSArray* create(JSGlobalData& globalData, Structure* structure, unsigned initialLength = 0)
        {
            JSArray* array = new (NotNull, allocateCell<JSArray>(globalData.heap)) JSArray(globalData, structure);
            array->finishCreation(globalData, initialLength);
            return array;
        }

        // tryCreateUninitialized is used for fast construction of arrays whose size and
        // contents are known at time of creation. Clients of this interface must:
        //   - null-check the result (indicating out of memory, or otherwise unable to allocate vector).
        //   - call 'initializeIndex' for all properties in sequence, for 0 <= i < initialLength.
        //   - called 'completeInitialization' after all properties have been initialized.
        static JSArray* tryCreateUninitialized(JSGlobalData& globalData, Structure* structure, unsigned initialLength)
        {
            JSArray* array = new (NotNull, allocateCell<JSArray>(globalData.heap)) JSArray(globalData, structure);
            return array->tryFinishCreationUninitialized(globalData, initialLength);
        }

        JS_EXPORT_PRIVATE static bool defineOwnProperty(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&, bool throwException);

        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier&, PropertySlot&);
        JS_EXPORT_PRIVATE static bool getOwnPropertySlotByIndex(JSCell*, ExecState*, unsigned propertyName, PropertySlot&);
        static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);
        static void putByIndex(JSCell*, ExecState*, unsigned propertyName, JSValue);

        static JS_EXPORTDATA const ClassInfo s_info;
        
        unsigned length() const { return m_storage->m_length; }
        // OK to use on new arrays, but not if it might be a RegExpMatchArray.
        bool setLength(ExecState*, unsigned, bool throwException = false);

        void sort(ExecState*);
        void sort(ExecState*, JSValue compareFunction, CallType, const CallData&);
        void sortNumeric(ExecState*, JSValue compareFunction, CallType, const CallData&);

        void push(ExecState*, JSValue);
        JSValue pop(ExecState*);

        void shiftCount(ExecState*, unsigned count);
        void unshiftCount(ExecState*, unsigned count);

        bool canGetIndex(unsigned i) { return i < m_vectorLength && m_storage->m_vector[i]; }
        JSValue getIndex(unsigned i)
        {
            ASSERT(canGetIndex(i));
            return m_storage->m_vector[i].get();
        }

        bool canSetIndex(unsigned i) { return i < m_vectorLength; }
        void setIndex(JSGlobalData& globalData, unsigned i, JSValue v)
        {
            ASSERT(canSetIndex(i));
            
            WriteBarrier<Unknown>& x = m_storage->m_vector[i];
            if (!x) {
                ArrayStorage *storage = m_storage;
                ++storage->m_numValuesInVector;
                if (i >= storage->m_length)
                    storage->m_length = i + 1;
            }
            x.set(globalData, this, v);
        }
        
        inline void initializeIndex(JSGlobalData& globalData, unsigned i, JSValue v)
        {
            ASSERT(canSetIndex(i));
            ArrayStorage *storage = m_storage;
#if CHECK_ARRAY_CONSISTENCY
            ASSERT(storage->m_inCompactInitialization);
#endif
            // Check that we are initializing the next index in sequence.
            ASSERT_UNUSED(i, i == storage->m_length);
            // tryCreateUninitialized set m_numValuesInVector to the initialLength,
            // check we do not try to initialize more than this number of properties.
            ASSERT(storage->m_length < storage->m_numValuesInVector);
            // It is improtant that we increment length here, so that all newly added
            // values in the array still get marked during the initialization phase.
            storage->m_vector[storage->m_length++].set(globalData, this, v);
        }

        inline void completeInitialization(unsigned newLength)
        {
            // Check that we have initialized as meny properties as we think we have.
            ASSERT_UNUSED(newLength, newLength == m_storage->m_length);
            // Check that the number of propreties initialized matches the initialLength.
            ASSERT(m_storage->m_length == m_storage->m_numValuesInVector);
#if CHECK_ARRAY_CONSISTENCY
            ASSERT(m_storage->m_inCompactInitialization);
            m_storage->m_inCompactInitialization = false;
#endif
        }

        bool inSparseMode()
        {
            SparseArrayValueMap* map = m_sparseValueMap;
            return map && map->sparseMode();
        }

        void fillArgList(ExecState*, MarkedArgumentBuffer&);
        void copyToArguments(ExecState*, CallFrame*, uint32_t length);

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }
        
        static ptrdiff_t storageOffset()
        {
            return OBJECT_OFFSETOF(JSArray, m_storage);
        }

        static ptrdiff_t vectorLengthOffset()
        {
            return OBJECT_OFFSETOF(JSArray, m_vectorLength);
        }

        JS_EXPORT_PRIVATE static void visitChildren(JSCell*, SlotVisitor&);

    protected:
        static const unsigned StructureFlags = OverridesGetOwnPropertySlot | OverridesVisitChildren | OverridesGetPropertyNames | JSObject::StructureFlags;
        static void put(JSCell*, ExecState*, const Identifier& propertyName, JSValue, PutPropertySlot&);

        static bool deleteProperty(JSCell*, ExecState*, const Identifier& propertyName);
        static bool deletePropertyByIndex(JSCell*, ExecState*, unsigned propertyName);
        static void getOwnPropertyNames(JSObject*, ExecState*, PropertyNameArray&, EnumerationMode);

        JS_EXPORT_PRIVATE void* subclassData() const;
        JS_EXPORT_PRIVATE void setSubclassData(void*);

    private:
        bool isLengthWritable()
        {
            SparseArrayValueMap* map = m_sparseValueMap;
            return !map || !map->lengthIsReadOnly();
        }

        void setLengthWritable(ExecState*, bool writable);
        void putDescriptor(ExecState*, SparseArrayEntry*, PropertyDescriptor&, PropertyDescriptor& old);
        bool defineOwnNumericProperty(ExecState*, unsigned, PropertyDescriptor&, bool throwException);
        void enterSparseMode(JSGlobalData&);

        bool getOwnPropertySlotSlowCase(ExecState*, unsigned propertyName, PropertySlot&);
        void putByIndexBeyondVectorLength(ExecState*, unsigned propertyName, JSValue);

        unsigned getNewVectorLength(unsigned desiredLength);
        bool increaseVectorLength(JSGlobalData&, unsigned newLength);
        bool unshiftCountSlowCase(JSGlobalData&, unsigned count);
        
        unsigned compactForSorting(JSGlobalData&);

        enum ConsistencyCheckType { NormalConsistencyCheck, DestructorConsistencyCheck, SortConsistencyCheck };
        void checkConsistency(ConsistencyCheckType = NormalConsistencyCheck);

        unsigned m_vectorLength; // The valid length of m_vector
        unsigned m_indexBias; // The number of JSValue sized blocks before ArrayStorage.
        ArrayStorage *m_storage;

        // FIXME: Maybe SparseArrayValueMap should be put into its own JSCell?
        SparseArrayValueMap* m_sparseValueMap;
        void* m_subclassData; // A JSArray subclass can use this to fill the vector lazily.
    };

    JSArray* asArray(JSValue);

    inline JSArray* asArray(JSCell* cell)
    {
        ASSERT(cell->inherits(&JSArray::s_info));
        return static_cast<JSArray*>(cell);
    }

    inline JSArray* asArray(JSValue value)
    {
        return asArray(value.asCell());
    }

    inline bool isJSArray(JSCell* cell) { return cell->classInfo() == &JSArray::s_info; }
    inline bool isJSArray(JSValue v) { return v.isCell() && isJSArray(v.asCell()); }

    // Rule from ECMA 15.2 about what an array index is.
    // Must exactly match string form of an unsigned integer, and be less than 2^32 - 1.
    inline unsigned Identifier::toArrayIndex(bool& ok) const
    {
        unsigned i = toUInt32(ok);
        if (ok && i >= 0xFFFFFFFFU)
            ok = false;
        return i;
    }

} // namespace JSC

#endif // JSArray_h
