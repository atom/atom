/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2007, 2008, 2009 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 *
 */

#ifndef JSCell_h
#define JSCell_h

#include "CallData.h"
#include "CallFrame.h"
#include "ConstructData.h"
#include "Heap.h"
#include "JSLock.h"
#include "JSValueInlineMethods.h"
#include "SlotVisitor.h"
#include "WriteBarrier.h"
#include <wtf/Noncopyable.h>

namespace JSC {

    class JSGlobalObject;
    class Structure;
    class PropertyDescriptor;
    class PropertyNameArray;

    enum EnumerationMode {
        ExcludeDontEnumProperties,
        IncludeDontEnumProperties
    };

    enum TypedArrayType {
        TypedArrayNone,
        TypedArrayInt8,
        TypedArrayInt16,
        TypedArrayInt32,
        TypedArrayUint8,
        TypedArrayUint8Clamped,
        TypedArrayUint16,
        TypedArrayUint32,
        TypedArrayFloat32,
        TypedArrayFloat64
    };

    class JSCell {
        friend class JSValue;
        friend class MarkedBlock;

    public:
        enum CreatingEarlyCellTag { CreatingEarlyCell };
        JSCell(CreatingEarlyCellTag);

    protected:
        JSCell(JSGlobalData&, Structure*);
        JS_EXPORT_PRIVATE static void destroy(JSCell*);

    public:
        // Querying the type.
        bool isString() const;
        bool isObject() const;
        bool isGetterSetter() const;
        bool inherits(const ClassInfo*) const;
        bool isAPIValueWrapper() const;

        Structure* structure() const;
        void setStructure(JSGlobalData&, Structure*);
        void clearStructure() { m_structure.clear(); }

        // Extracting the value.
        JS_EXPORT_PRIVATE bool getString(ExecState* exec, UString&) const;
        JS_EXPORT_PRIVATE UString getString(ExecState* exec) const; // null string if not a string
        JS_EXPORT_PRIVATE JSObject* getObject(); // NULL if not an object
        const JSObject* getObject() const; // NULL if not an object
        
        JS_EXPORT_PRIVATE static CallType getCallData(JSCell*, CallData&);
        JS_EXPORT_PRIVATE static ConstructType getConstructData(JSCell*, ConstructData&);

        // Basic conversions.
        JS_EXPORT_PRIVATE JSValue toPrimitive(ExecState*, PreferredPrimitiveType) const;
        bool getPrimitiveNumber(ExecState*, double& number, JSValue&) const;
        bool toBoolean(ExecState*) const;
        JS_EXPORT_PRIVATE double toNumber(ExecState*) const;
        JS_EXPORT_PRIVATE JSObject* toObject(ExecState*, JSGlobalObject*) const;

        static void visitChildren(JSCell*, SlotVisitor&);

        // Object operations, with the toObject operation included.
        const ClassInfo* classInfo() const;
        const ClassInfo* validatedClassInfo() const;
        const MethodTable* methodTable() const;
        static void put(JSCell*, ExecState*, const Identifier& propertyName, JSValue, PutPropertySlot&);
        static void putByIndex(JSCell*, ExecState*, unsigned propertyName, JSValue);
        
        static bool deleteProperty(JSCell*, ExecState*, const Identifier& propertyName);
        static bool deletePropertyByIndex(JSCell*, ExecState*, unsigned propertyName);

        static JSObject* toThisObject(JSCell*, ExecState*);

        void zap() { *reinterpret_cast<uintptr_t**>(this) = 0; }
        bool isZapped() const { return !*reinterpret_cast<uintptr_t* const*>(this); }

        // FIXME: Rename getOwnPropertySlot to virtualGetOwnPropertySlot, and
        // fastGetOwnPropertySlot to getOwnPropertySlot. Callers should always
        // call this function, not its slower virtual counterpart. (For integer
        // property names, we want a similar interface with appropriate optimizations.)
        bool fastGetOwnPropertySlot(ExecState*, const Identifier& propertyName, PropertySlot&);
        JSValue fastGetOwnProperty(ExecState*, const UString&);

        static ptrdiff_t structureOffset()
        {
            return OBJECT_OFFSETOF(JSCell, m_structure);
        }

        static ptrdiff_t classInfoOffset()
        {
            return OBJECT_OFFSETOF(JSCell, m_classInfo);
        }
        
        void* structureAddress()
        {
            return &m_structure;
        }

#if ENABLE(GC_VALIDATION)
        Structure* unvalidatedStructure() { return m_structure.unvalidatedGet(); }
#endif
        
        static const TypedArrayType TypedArrayStorageType = TypedArrayNone;
    protected:

        void finishCreation(JSGlobalData&);
        void finishCreation(JSGlobalData&, Structure*, CreatingEarlyCellTag);

        // Base implementation; for non-object classes implements getPropertySlot.
        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier& propertyName, PropertySlot&);
        static bool getOwnPropertySlotByIndex(JSCell*, ExecState*, unsigned propertyName, PropertySlot&);

        // Dummy implementations of override-able static functions for classes to put in their MethodTable
        static NO_RETURN_DUE_TO_ASSERT void defineGetter(JSObject*, ExecState*, const Identifier&, JSObject*, unsigned);
        static NO_RETURN_DUE_TO_ASSERT void defineSetter(JSObject*, ExecState*, const Identifier& propertyName, JSObject* setterFunction, unsigned attributes = 0);
        static JSValue defaultValue(const JSObject*, ExecState*, PreferredPrimitiveType);
        static NO_RETURN_DUE_TO_ASSERT void getOwnPropertyNames(JSObject*, ExecState*, PropertyNameArray&, EnumerationMode);
        static NO_RETURN_DUE_TO_ASSERT void getPropertyNames(JSObject*, ExecState*, PropertyNameArray&, EnumerationMode);
        static UString className(const JSObject*);
        static bool hasInstance(JSObject*, ExecState*, JSValue, JSValue prototypeProperty);
        static NO_RETURN_DUE_TO_ASSERT void putDirectVirtual(JSObject*, ExecState*, const Identifier& propertyName, JSValue, unsigned attributes);
        static bool defineOwnProperty(JSObject*, ExecState*, const Identifier& propertyName, PropertyDescriptor&, bool shouldThrow);
        static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);

    private:
        const ClassInfo* m_classInfo;
        WriteBarrier<Structure> m_structure;
    };

    inline JSCell::JSCell(CreatingEarlyCellTag)
    {
    }

    inline void JSCell::finishCreation(JSGlobalData& globalData)
    {
#if ENABLE(GC_VALIDATION)
        ASSERT(globalData.isInitializingObject());
        globalData.setInitializingObject(false);
#else
        UNUSED_PARAM(globalData);
#endif
        ASSERT(m_structure);
    }

    inline Structure* JSCell::structure() const
    {
        return m_structure.get();
    }

    inline const ClassInfo* JSCell::classInfo() const
    {
        return m_classInfo;
    }

    inline void JSCell::visitChildren(JSCell* cell, SlotVisitor& visitor)
    {
        visitor.append(&cell->m_structure);
    }

    // --- JSValue inlines ----------------------------

    inline bool JSValue::isString() const
    {
        return isCell() && asCell()->isString();
    }

    inline bool JSValue::isPrimitive() const
    {
        return !isCell() || asCell()->isString();
    }

    inline bool JSValue::isGetterSetter() const
    {
        return isCell() && asCell()->isGetterSetter();
    }

    inline bool JSValue::isObject() const
    {
        return isCell() && asCell()->isObject();
    }

    inline bool JSValue::getString(ExecState* exec, UString& s) const
    {
        return isCell() && asCell()->getString(exec, s);
    }

    inline UString JSValue::getString(ExecState* exec) const
    {
        return isCell() ? asCell()->getString(exec) : UString();
    }

    template <typename Base> UString HandleConverter<Base, Unknown>::getString(ExecState* exec) const
    {
        return jsValue().getString(exec);
    }

    inline JSObject* JSValue::getObject() const
    {
        return isCell() ? asCell()->getObject() : 0;
    }

    ALWAYS_INLINE bool JSValue::getUInt32(uint32_t& v) const
    {
        if (isInt32()) {
            int32_t i = asInt32();
            v = static_cast<uint32_t>(i);
            return i >= 0;
        }
        if (isDouble()) {
            double d = asDouble();
            v = static_cast<uint32_t>(d);
            return v == d;
        }
        return false;
    }

    inline JSValue JSValue::toPrimitive(ExecState* exec, PreferredPrimitiveType preferredType) const
    {
        return isCell() ? asCell()->toPrimitive(exec, preferredType) : asValue();
    }

    inline bool JSValue::getPrimitiveNumber(ExecState* exec, double& number, JSValue& value)
    {
        if (isInt32()) {
            number = asInt32();
            value = *this;
            return true;
        }
        if (isDouble()) {
            number = asDouble();
            value = *this;
            return true;
        }
        if (isCell())
            return asCell()->getPrimitiveNumber(exec, number, value);
        if (isTrue()) {
            number = 1.0;
            value = *this;
            return true;
        }
        if (isFalse() || isNull()) {
            number = 0.0;
            value = *this;
            return true;
        }
        ASSERT(isUndefined());
        number = std::numeric_limits<double>::quiet_NaN();
        value = *this;
        return true;
    }

    ALWAYS_INLINE double JSValue::toNumber(ExecState* exec) const
    {
        if (isInt32())
            return asInt32();
        if (isDouble())
            return asDouble();
        return toNumberSlowCase(exec);
    }

    inline JSObject* JSValue::toObject(ExecState* exec) const
    {
        return isCell() ? asCell()->toObject(exec, exec->lexicalGlobalObject()) : toObjectSlowCase(exec, exec->lexicalGlobalObject());
    }

    inline JSObject* JSValue::toObject(ExecState* exec, JSGlobalObject* globalObject) const
    {
        return isCell() ? asCell()->toObject(exec, globalObject) : toObjectSlowCase(exec, globalObject);
    }

    template <typename T> void* allocateCell(Heap& heap)
    {
#if ENABLE(GC_VALIDATION)
        ASSERT(sizeof(T) == T::s_info.cellSize);
        ASSERT(!heap.globalData()->isInitializingObject());
        heap.globalData()->setInitializingObject(true);
#endif
        JSCell* result = static_cast<JSCell*>(heap.allocate(sizeof(T)));
        result->clearStructure();
        return result;
    }
    
    inline bool isZapped(const JSCell* cell)
    {
        return cell->isZapped();
    }

    template<typename To, typename From>
    inline To jsCast(From* from)
    {
        ASSERT(from->inherits(&WTF::RemovePointer<To>::Type::s_info));
        return static_cast<To>(from);
    }

    template<typename To, typename From>
    inline To jsDynamicCast(From* from)
    {
        return from->inherits(&WTF::RemovePointer<To>::Type::s_info) ? static_cast<To>(from) : 0;
    }

} // namespace JSC

#endif // JSCell_h
