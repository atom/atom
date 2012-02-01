/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef JSObject_h
#define JSObject_h

#include "ArgList.h"
#include "ClassInfo.h"
#include "CommonIdentifiers.h"
#include "CallFrame.h"
#include "JSCell.h"
#include "PropertySlot.h"
#include "PutPropertySlot.h"
#include "ScopeChain.h"
#include "StorageBarrier.h"
#include "Structure.h"
#include "JSGlobalData.h"
#include "JSString.h"
#include <wtf/StdLibExtras.h>

namespace JSC {

    inline JSCell* getJSFunction(JSValue value)
    {
        if (value.isCell() && (value.asCell()->structure()->typeInfo().type() == JSFunctionType))
            return value.asCell();
        return 0;
    }

    class GetterSetter;
    class HashEntry;
    class InternalFunction;
    class MarkedBlock;
    class PropertyDescriptor;
    class PropertyNameArray;
    class Structure;
    struct HashTable;

    JS_EXPORT_PRIVATE JSObject* throwTypeError(ExecState*, const UString&);
    extern JS_EXPORTDATA const char* StrictModeReadonlyPropertyWriteError;

    // ECMA 262-3 8.6.1
    // Property attributes
    enum Attribute {
        None         = 0,
        ReadOnly     = 1 << 1,  // property can be only read, not written
        DontEnum     = 1 << 2,  // property doesn't appear in (for .. in ..)
        DontDelete   = 1 << 3,  // property can't be deleted
        Function     = 1 << 4,  // property is a function - only used by static hashtables
        Accessor     = 1 << 5,  // property is a getter/setter
    };

    class JSObject : public JSCell {
        friend class BatchedTransitionOptimizer;
        friend class JIT;
        friend class JSCell;
        friend class MarkedBlock;
        JS_EXPORT_PRIVATE friend bool setUpStaticFunctionSlot(ExecState* exec, const HashEntry* entry, JSObject* thisObj, const Identifier& propertyName, PropertySlot& slot);

        enum PutMode {
            PutModePut,
            PutModeDefineOwnProperty,
        };

    public:
        typedef JSCell Base;

        JS_EXPORT_PRIVATE static void destroy(JSCell*);

        JS_EXPORT_PRIVATE static void visitChildren(JSCell*, SlotVisitor&);

        JS_EXPORT_PRIVATE static UString className(const JSObject*);

        JSValue prototype() const;
        void setPrototype(JSGlobalData&, JSValue prototype);
        bool setPrototypeWithCycleCheck(JSGlobalData&, JSValue prototype);
        
        Structure* inheritorID(JSGlobalData&);

        JSValue get(ExecState*, const Identifier& propertyName) const;
        JSValue get(ExecState*, unsigned propertyName) const;

        bool getPropertySlot(ExecState*, const Identifier& propertyName, PropertySlot&);
        bool getPropertySlot(ExecState*, unsigned propertyName, PropertySlot&);
        JS_EXPORT_PRIVATE bool getPropertyDescriptor(ExecState*, const Identifier& propertyName, PropertyDescriptor&);

        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier& propertyName, PropertySlot&);
        JS_EXPORT_PRIVATE static bool getOwnPropertySlotByIndex(JSCell*, ExecState*, unsigned propertyName, PropertySlot&);
        JS_EXPORT_PRIVATE static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);

        JS_EXPORT_PRIVATE static void put(JSCell*, ExecState*, const Identifier& propertyName, JSValue, PutPropertySlot&);
        JS_EXPORT_PRIVATE static void putByIndex(JSCell*, ExecState*, unsigned propertyName, JSValue);

        // putDirect is effectively an unchecked vesion of 'defineOwnProperty':
        //  - the prototype chain is not consulted
        //  - accessors are not called.
        //  - attributes will be respected (after the call the property will exist with the given attributes)
        JS_EXPORT_PRIVATE static void putDirectVirtual(JSObject*, ExecState*, const Identifier& propertyName, JSValue, unsigned attributes);
        void putDirect(JSGlobalData&, const Identifier& propertyName, JSValue, unsigned attributes = 0);
        void putDirect(JSGlobalData&, const Identifier& propertyName, JSValue, PutPropertySlot&);
        void putDirectWithoutTransition(JSGlobalData&, const Identifier& propertyName, JSValue, unsigned attributes = 0);

        bool propertyIsEnumerable(ExecState*, const Identifier& propertyName) const;

        JS_EXPORT_PRIVATE bool hasProperty(ExecState*, const Identifier& propertyName) const;
        JS_EXPORT_PRIVATE bool hasProperty(ExecState*, unsigned propertyName) const;
        bool hasOwnProperty(ExecState*, const Identifier& propertyName) const;

        JS_EXPORT_PRIVATE static bool deleteProperty(JSCell*, ExecState*, const Identifier& propertyName);
        JS_EXPORT_PRIVATE static bool deletePropertyByIndex(JSCell*, ExecState*, unsigned propertyName);

        JS_EXPORT_PRIVATE static JSValue defaultValue(const JSObject*, ExecState*, PreferredPrimitiveType);

        JS_EXPORT_PRIVATE static bool hasInstance(JSObject*, ExecState*, JSValue, JSValue prototypeProperty);

        JS_EXPORT_PRIVATE static void getOwnPropertyNames(JSObject*, ExecState*, PropertyNameArray&, EnumerationMode);
        JS_EXPORT_PRIVATE static void getPropertyNames(JSObject*, ExecState*, PropertyNameArray&, EnumerationMode);

        JSValue toPrimitive(ExecState*, PreferredPrimitiveType = NoPreference) const;
        JS_EXPORT_PRIVATE bool toBoolean(ExecState*) const;
        bool getPrimitiveNumber(ExecState*, double& number, JSValue&) const;
        JS_EXPORT_PRIVATE double toNumber(ExecState*) const;
        JS_EXPORT_PRIVATE JSString* toString(ExecState*) const;

        // NOTE: JSObject and its subclasses must be able to gracefully handle ExecState* = 0,
        // because this call may come from inside the compiler.
        JS_EXPORT_PRIVATE static JSObject* toThisObject(JSCell*, ExecState*);
        JSObject* unwrappedObject();

        bool getPropertySpecificValue(ExecState* exec, const Identifier& propertyName, JSCell*& specificFunction) const;

        // This get function only looks at the property map.
        JSValue getDirect(JSGlobalData& globalData, const Identifier& propertyName) const
        {
            size_t offset = structure()->get(globalData, propertyName);
            return offset != WTF::notFound ? getDirectOffset(offset) : JSValue();
        }

        WriteBarrierBase<Unknown>* getDirectLocation(JSGlobalData& globalData, const Identifier& propertyName)
        {
            size_t offset = structure()->get(globalData, propertyName);
            return offset != WTF::notFound ? locationForOffset(offset) : 0;
        }

        WriteBarrierBase<Unknown>* getDirectLocation(JSGlobalData& globalData, const Identifier& propertyName, unsigned& attributes)
        {
            JSCell* specificFunction;
            size_t offset = structure()->get(globalData, propertyName, attributes, specificFunction);
            return offset != WTF::notFound ? locationForOffset(offset) : 0;
        }

        size_t offsetForLocation(WriteBarrierBase<Unknown>* location) const
        {
            return location - propertyStorage();
        }

        void transitionTo(JSGlobalData&, Structure*);

        void removeDirect(JSGlobalData&, const Identifier& propertyName);
        bool hasCustomProperties() { return structure()->didTransition(); }
        bool hasGetterSetterProperties() { return structure()->hasGetterSetterProperties(); }

        // putOwnDataProperty has 'put' like semantics, however this method:
        //  - assumes the object contains no own getter/setter properties.
        //  - provides no special handling for __proto__
        //  - does not walk the prototype chain (to check for accessors or non-writable properties).
        // This is used by JSActivation.
        bool putOwnDataProperty(JSGlobalData&, const Identifier& propertyName, JSValue, PutPropertySlot&);

        // Fast access to known property offsets.
        JSValue getDirectOffset(size_t offset) const { return propertyStorage()[offset].get(); }
        void putDirectOffset(JSGlobalData& globalData, size_t offset, JSValue value) { propertyStorage()[offset].set(globalData, this, value); }
        void putUndefinedAtDirectOffset(size_t offset) { propertyStorage()[offset].setUndefined(); }

        JS_EXPORT_PRIVATE void fillGetterPropertySlot(PropertySlot&, WriteBarrierBase<Unknown>* location);
        void initializeGetterSetterProperty(ExecState*, const Identifier&, GetterSetter*, unsigned attributes);

        JS_EXPORT_PRIVATE static void defineGetter(JSObject*, ExecState*, const Identifier& propertyName, JSObject* getterFunction, unsigned attributes = 0);
        JS_EXPORT_PRIVATE static void defineSetter(JSObject*, ExecState*, const Identifier& propertyName, JSObject* setterFunction, unsigned attributes = 0);
        JS_EXPORT_PRIVATE JSValue lookupGetter(ExecState*, const Identifier& propertyName);
        JS_EXPORT_PRIVATE JSValue lookupSetter(ExecState*, const Identifier& propertyName);
        JS_EXPORT_PRIVATE static bool defineOwnProperty(JSObject*, ExecState*, const Identifier& propertyName, PropertyDescriptor&, bool shouldThrow);

        bool isGlobalObject() const;
        bool isVariableObject() const;
        bool isActivationObject() const;
        bool isErrorInstance() const;
        bool isGlobalThis() const;

        void seal(JSGlobalData&);
        void freeze(JSGlobalData&);
        JS_EXPORT_PRIVATE void preventExtensions(JSGlobalData&);
        bool isSealed(JSGlobalData& globalData) { return structure()->isSealed(globalData); }
        bool isFrozen(JSGlobalData& globalData) { return structure()->isFrozen(globalData); }
        bool isExtensible() { return structure()->isExtensible(); }

        bool staticFunctionsReified() { return structure()->staticFunctionsReified(); }
        void reifyStaticFunctionsForDelete(ExecState* exec);

        JS_EXPORT_PRIVATE void allocatePropertyStorage(JSGlobalData&, size_t oldSize, size_t newSize);
        bool isUsingInlineStorage() const { return static_cast<const void*>(m_propertyStorage.get()) == static_cast<const void*>(this + 1); }

        void* addressOfPropertyStorage()
        {
            return &m_propertyStorage;
        }

        static const unsigned baseExternalStorageCapacity = 16;

        void flattenDictionaryObject(JSGlobalData& globalData)
        {
            structure()->flattenDictionaryStructure(globalData, this);
        }

        JSGlobalObject* globalObject() const
        {
            ASSERT(structure()->globalObject());
            ASSERT(!isGlobalObject() || ((JSObject*)structure()->globalObject()) == this);
            return structure()->globalObject();
        }
        
        static size_t offsetOfInlineStorage();
        static size_t offsetOfPropertyStorage();
        static size_t offsetOfInheritorID();

        static JS_EXPORTDATA const ClassInfo s_info;

    protected:
        void finishCreation(JSGlobalData& globalData, PropertyStorage inlineStorage)
        {
            Base::finishCreation(globalData);
            ASSERT(inherits(&s_info));
            ASSERT(structure()->propertyStorageCapacity() < baseExternalStorageCapacity);
            ASSERT(structure()->isEmpty());
            ASSERT(prototype().isNull() || Heap::heap(this) == Heap::heap(prototype()));
            ASSERT_UNUSED(inlineStorage, static_cast<void*>(inlineStorage) == static_cast<void*>(this + 1));
            ASSERT(structure()->isObject());
            ASSERT(classInfo());
        }

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

        static const unsigned StructureFlags = 0;

        // To instantiate objects you likely want JSFinalObject, below.
        // To create derived types you likely want JSNonFinalObject, below.
        JSObject(JSGlobalData&, Structure*, PropertyStorage inlineStorage);

    private:
        // Nobody should ever ask any of these questions on something already known to be a JSObject.
        using JSCell::isAPIValueWrapper;
        using JSCell::isGetterSetter;
        void getObject();
        void getString(ExecState* exec);
        void isObject();
        void isString();
        
        ConstPropertyStorage propertyStorage() const { return m_propertyStorage.get(); }
        PropertyStorage propertyStorage() { return m_propertyStorage.get(); }

        const WriteBarrierBase<Unknown>* locationForOffset(size_t offset) const
        {
            return &propertyStorage()[offset];
        }

        WriteBarrierBase<Unknown>* locationForOffset(size_t offset)
        {
            return &propertyStorage()[offset];
        }

        template<PutMode>
        bool putDirectInternal(JSGlobalData&, const Identifier& propertyName, JSValue, unsigned attr, PutPropertySlot&, JSCell*);

        bool inlineGetOwnPropertySlot(ExecState*, const Identifier& propertyName, PropertySlot&);

        const HashEntry* findPropertyHashEntry(ExecState*, const Identifier& propertyName) const;
        Structure* createInheritorID(JSGlobalData&);

        StorageBarrier m_propertyStorage;
        WriteBarrier<Structure> m_inheritorID;
    };


#if USE(JSVALUE32_64)
#define JSNonFinalObject_inlineStorageCapacity 4
#define JSFinalObject_inlineStorageCapacity 6
#else
#define JSNonFinalObject_inlineStorageCapacity 2
#define JSFinalObject_inlineStorageCapacity 4
#endif

COMPILE_ASSERT((JSFinalObject_inlineStorageCapacity >= JSNonFinalObject_inlineStorageCapacity), final_storage_is_at_least_as_large_as_non_final);

    // JSNonFinalObject is a type of JSObject that has some internal storage,
    // but also preserves some space in the collector cell for additional
    // data members in derived types.
    class JSNonFinalObject : public JSObject {
        friend class JSObject;

    public:
        typedef JSObject Base;

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

        JS_EXPORT_PRIVATE static void destroy(JSCell*);

    protected:
        explicit JSNonFinalObject(JSGlobalData& globalData, Structure* structure)
            : JSObject(globalData, structure, m_inlineStorage)
        {
        }

        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData, m_inlineStorage);
            ASSERT(!(OBJECT_OFFSETOF(JSNonFinalObject, m_inlineStorage) % sizeof(double)));
            ASSERT(this->structure()->propertyStorageCapacity() == JSNonFinalObject_inlineStorageCapacity);
            ASSERT(classInfo());
        }

    private:
        WriteBarrier<Unknown> m_inlineStorage[JSNonFinalObject_inlineStorageCapacity];
    };

    // JSFinalObject is a type of JSObject that contains sufficent internal
    // storage to fully make use of the colloctor cell containing it.
    class JSFinalObject : public JSObject {
        friend class JSObject;

    public:
        typedef JSObject Base;

        static JSFinalObject* create(ExecState* exec, Structure* structure)
        {
            JSFinalObject* finalObject = new (NotNull, allocateCell<JSFinalObject>(*exec->heap())) JSFinalObject(exec->globalData(), structure);
            finalObject->finishCreation(exec->globalData());
            return finalObject;
        }

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(FinalObjectType, StructureFlags), &s_info);
        }

        static JS_EXPORTDATA const ClassInfo s_info;

    protected:
        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData, m_inlineStorage);
            ASSERT(!(OBJECT_OFFSETOF(JSFinalObject, m_inlineStorage) % sizeof(double)));
            ASSERT(this->structure()->propertyStorageCapacity() == JSFinalObject_inlineStorageCapacity);
            ASSERT(classInfo());
        }

        static void destroy(JSCell*);

    private:
        explicit JSFinalObject(JSGlobalData& globalData, Structure* structure)
            : JSObject(globalData, structure, m_inlineStorage)
        {
        }

        static const unsigned StructureFlags = JSObject::StructureFlags;

        WriteBarrierBase<Unknown> m_inlineStorage[JSFinalObject_inlineStorageCapacity];
    };

inline bool isJSFinalObject(JSCell* cell)
{
    return cell->classInfo() == &JSFinalObject::s_info;
}

inline bool isJSFinalObject(JSValue value)
{
    return value.isCell() && isJSFinalObject(value.asCell());
}

inline size_t JSObject::offsetOfInlineStorage()
{
    ASSERT(OBJECT_OFFSETOF(JSFinalObject, m_inlineStorage) == OBJECT_OFFSETOF(JSNonFinalObject, m_inlineStorage));
    return OBJECT_OFFSETOF(JSFinalObject, m_inlineStorage);
}

inline size_t JSObject::offsetOfPropertyStorage()
{
    return OBJECT_OFFSETOF(JSObject, m_propertyStorage);
}

inline size_t JSObject::offsetOfInheritorID()
{
    return OBJECT_OFFSETOF(JSObject, m_inheritorID);
}

inline bool JSObject::isGlobalObject() const
{
    return structure()->typeInfo().type() == GlobalObjectType;
}

inline bool JSObject::isVariableObject() const
{
    return structure()->typeInfo().type() >= VariableObjectType;
}

inline bool JSObject::isActivationObject() const
{
    return structure()->typeInfo().type() == ActivationObjectType;
}

inline bool JSObject::isErrorInstance() const
{
    return structure()->typeInfo().type() == ErrorInstanceType;
}

inline bool JSObject::isGlobalThis() const
{
    return structure()->typeInfo().type() == GlobalThisType;
}

inline JSObject* constructEmptyObject(ExecState* exec, Structure* structure)
{
    return JSFinalObject::create(exec, structure);
}

inline CallType getCallData(JSValue value, CallData& callData)
{
    CallType result = value.isCell() ? value.asCell()->methodTable()->getCallData(value.asCell(), callData) : CallTypeNone;
    ASSERT(result == CallTypeNone || value.isValidCallee());
    return result;
}

inline ConstructType getConstructData(JSValue value, ConstructData& constructData)
{
    ConstructType result = value.isCell() ? value.asCell()->methodTable()->getConstructData(value.asCell(), constructData) : ConstructTypeNone;
    ASSERT(result == ConstructTypeNone || value.isValidCallee());
    return result;
}

inline Structure* createEmptyObjectStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
{
    return JSFinalObject::createStructure(globalData, globalObject, prototype);
}

inline JSObject* asObject(JSCell* cell)
{
    ASSERT(cell->isObject());
    return static_cast<JSObject*>(cell);
}

inline JSObject* asObject(JSValue value)
{
    return asObject(value.asCell());
}

inline JSObject::JSObject(JSGlobalData& globalData, Structure* structure, PropertyStorage inlineStorage)
    : JSCell(globalData, structure)
    , m_propertyStorage(globalData, this, inlineStorage)
{
}

inline JSValue JSObject::prototype() const
{
    return structure()->storedPrototype();
}

inline bool JSObject::setPrototypeWithCycleCheck(JSGlobalData& globalData, JSValue prototype)
{
    JSValue nextPrototypeValue = prototype;
    while (nextPrototypeValue && nextPrototypeValue.isObject()) {
        JSObject* nextPrototype = asObject(nextPrototypeValue)->unwrappedObject();
        if (nextPrototype == this)
            return false;
        nextPrototypeValue = nextPrototype->prototype();
    }
    setPrototype(globalData, prototype);
    return true;
}

inline void JSObject::setPrototype(JSGlobalData& globalData, JSValue prototype)
{
    ASSERT(prototype);
    setStructure(globalData, Structure::changePrototypeTransition(globalData, structure(), prototype));
}

inline Structure* JSObject::inheritorID(JSGlobalData& globalData)
{
    if (m_inheritorID) {
        ASSERT(m_inheritorID->isEmpty());
        return m_inheritorID.get();
    }
    return createInheritorID(globalData);
}

inline bool Structure::isUsingInlineStorage() const
{
    return propertyStorageCapacity() < JSObject::baseExternalStorageCapacity;
}

inline bool JSCell::inherits(const ClassInfo* info) const
{
    return classInfo()->isSubClassOf(info);
}

inline const MethodTable* JSCell::methodTable() const
{
    return &classInfo()->methodTable;
}

// this method is here to be after the inline declaration of JSCell::inherits
inline bool JSValue::inherits(const ClassInfo* classInfo) const
{
    return isCell() && asCell()->inherits(classInfo);
}

inline JSObject* JSValue::toThisObject(ExecState* exec) const
{
    return isCell() ? asCell()->methodTable()->toThisObject(asCell(), exec) : toThisObjectSlowCase(exec);
}

ALWAYS_INLINE bool JSObject::inlineGetOwnPropertySlot(ExecState* exec, const Identifier& propertyName, PropertySlot& slot)
{
    if (WriteBarrierBase<Unknown>* location = getDirectLocation(exec->globalData(), propertyName)) {
        if (structure()->hasGetterSetterProperties() && location->isGetterSetter())
            fillGetterPropertySlot(slot, location);
        else
            slot.setValue(this, location->get(), offsetForLocation(location));
        return true;
    }

    // non-standard Netscape extension
    if (propertyName == exec->propertyNames().underscoreProto) {
        slot.setValue(prototype());
        return true;
    }

    return false;
}

// It may seem crazy to inline a function this large, especially a virtual function,
// but it makes a big difference to property lookup that derived classes can inline their
// base class call to this.
ALWAYS_INLINE bool JSObject::getOwnPropertySlot(JSCell* cell, ExecState* exec, const Identifier& propertyName, PropertySlot& slot)
{
    return jsCast<JSObject*>(cell)->inlineGetOwnPropertySlot(exec, propertyName, slot);
}

ALWAYS_INLINE bool JSCell::fastGetOwnPropertySlot(ExecState* exec, const Identifier& propertyName, PropertySlot& slot)
{
    if (!structure()->typeInfo().overridesGetOwnPropertySlot())
        return asObject(this)->inlineGetOwnPropertySlot(exec, propertyName, slot);
    return methodTable()->getOwnPropertySlot(this, exec, propertyName, slot);
}

// Fast call to get a property where we may not yet have converted the string to an
// identifier. The first time we perform a property access with a given string, try
// performing the property map lookup without forming an identifier. We detect this
// case by checking whether the hash has yet been set for this string.
ALWAYS_INLINE JSValue JSCell::fastGetOwnProperty(ExecState* exec, const UString& name)
{
    if (!structure()->typeInfo().overridesGetOwnPropertySlot() && !structure()->hasGetterSetterProperties()) {
        size_t offset = name.impl()->hasHash()
            ? structure()->get(exec->globalData(), Identifier(exec, name))
            : structure()->get(exec->globalData(), name);
        if (offset != WTF::notFound)
            return asObject(this)->locationForOffset(offset)->get();
    }
    return JSValue();
}

// It may seem crazy to inline a function this large but it makes a big difference
// since this is function very hot in variable lookup
ALWAYS_INLINE bool JSObject::getPropertySlot(ExecState* exec, const Identifier& propertyName, PropertySlot& slot)
{
    JSObject* object = this;
    while (true) {
        if (object->fastGetOwnPropertySlot(exec, propertyName, slot))
            return true;
        JSValue prototype = object->prototype();
        if (!prototype.isObject())
            return false;
        object = asObject(prototype);
    }
}

ALWAYS_INLINE bool JSObject::getPropertySlot(ExecState* exec, unsigned propertyName, PropertySlot& slot)
{
    JSObject* object = this;
    while (true) {
        if (object->methodTable()->getOwnPropertySlotByIndex(object, exec, propertyName, slot))
            return true;
        JSValue prototype = object->prototype();
        if (!prototype.isObject())
            return false;
        object = asObject(prototype);
    }
}

inline JSValue JSObject::get(ExecState* exec, const Identifier& propertyName) const
{
    PropertySlot slot(this);
    if (const_cast<JSObject*>(this)->getPropertySlot(exec, propertyName, slot))
        return slot.getValue(exec, propertyName);
    
    return jsUndefined();
}

inline JSValue JSObject::get(ExecState* exec, unsigned propertyName) const
{
    PropertySlot slot(this);
    if (const_cast<JSObject*>(this)->getPropertySlot(exec, propertyName, slot))
        return slot.getValue(exec, propertyName);

    return jsUndefined();
}

template<JSObject::PutMode mode>
inline bool JSObject::putDirectInternal(JSGlobalData& globalData, const Identifier& propertyName, JSValue value, unsigned attributes, PutPropertySlot& slot, JSCell* specificFunction)
{
    ASSERT(value);
    ASSERT(!Heap::heap(value) || Heap::heap(value) == Heap::heap(this));

    if (structure()->isDictionary()) {
        unsigned currentAttributes;
        JSCell* currentSpecificFunction;
        size_t offset = structure()->get(globalData, propertyName, currentAttributes, currentSpecificFunction);
        if (offset != WTF::notFound) {
            // If there is currently a specific function, and there now either isn't,
            // or the new value is different, then despecify.
            if (currentSpecificFunction && (specificFunction != currentSpecificFunction))
                structure()->despecifyDictionaryFunction(globalData, propertyName);
            if ((mode == PutModePut) && currentAttributes & ReadOnly)
                return false;

            putDirectOffset(globalData, offset, value);
            // At this point, the objects structure only has a specific value set if previously there
            // had been one set, and if the new value being specified is the same (otherwise we would
            // have despecified, above).  So, if currentSpecificFunction is not set, or if the new
            // value is different (or there is no new value), then the slot now has no value - and
            // as such it is cachable.
            // If there was previously a value, and the new value is the same, then we cannot cache.
            if (!currentSpecificFunction || (specificFunction != currentSpecificFunction))
                slot.setExistingProperty(this, offset);
            return true;
        }

        if ((mode == PutModePut) && !isExtensible())
            return false;

        size_t currentCapacity = structure()->propertyStorageCapacity();
        offset = structure()->addPropertyWithoutTransition(globalData, propertyName, attributes, specificFunction);
        if (currentCapacity != structure()->propertyStorageCapacity())
            allocatePropertyStorage(globalData, currentCapacity, structure()->propertyStorageCapacity());

        ASSERT(offset < structure()->propertyStorageCapacity());
        putDirectOffset(globalData, offset, value);
        // See comment on setNewProperty call below.
        if (!specificFunction)
            slot.setNewProperty(this, offset);
        return true;
    }

    size_t offset;
    size_t currentCapacity = structure()->propertyStorageCapacity();
    if (Structure* structure = Structure::addPropertyTransitionToExistingStructure(this->structure(), propertyName, attributes, specificFunction, offset)) {    
        if (currentCapacity != structure->propertyStorageCapacity())
            allocatePropertyStorage(globalData, currentCapacity, structure->propertyStorageCapacity());

        ASSERT(offset < structure->propertyStorageCapacity());
        setStructure(globalData, structure);
        putDirectOffset(globalData, offset, value);
        // This is a new property; transitions with specific values are not currently cachable,
        // so leave the slot in an uncachable state.
        if (!specificFunction)
            slot.setNewProperty(this, offset);
        return true;
    }

    unsigned currentAttributes;
    JSCell* currentSpecificFunction;
    offset = structure()->get(globalData, propertyName, currentAttributes, currentSpecificFunction);
    if (offset != WTF::notFound) {
        if ((mode == PutModePut) && currentAttributes & ReadOnly)
            return false;

        // There are three possibilities here:
        //  (1) There is an existing specific value set, and we're overwriting with *the same value*.
        //       * Do nothing - no need to despecify, but that means we can't cache (a cached
        //         put could write a different value). Leave the slot in an uncachable state.
        //  (2) There is a specific value currently set, but we're writing a different value.
        //       * First, we have to despecify.  Having done so, this is now a regular slot
        //         with no specific value, so go ahead & cache like normal.
        //  (3) Normal case, there is no specific value set.
        //       * Go ahead & cache like normal.
        if (currentSpecificFunction) {
            // case (1) Do the put, then return leaving the slot uncachable.
            if (specificFunction == currentSpecificFunction) {
                putDirectOffset(globalData, offset, value);
                return true;
            }
            // case (2) Despecify, fall through to (3).
            setStructure(globalData, Structure::despecifyFunctionTransition(globalData, structure(), propertyName));
        }

        // case (3) set the slot, do the put, return.
        slot.setExistingProperty(this, offset);
        putDirectOffset(globalData, offset, value);
        return true;
    }

    if ((mode == PutModePut) && !isExtensible())
        return false;

    Structure* structure = Structure::addPropertyTransition(globalData, this->structure(), propertyName, attributes, specificFunction, offset);

    if (currentCapacity != structure->propertyStorageCapacity())
        allocatePropertyStorage(globalData, currentCapacity, structure->propertyStorageCapacity());

    ASSERT(offset < structure->propertyStorageCapacity());
    setStructure(globalData, structure);
    putDirectOffset(globalData, offset, value);
    // This is a new property; transitions with specific values are not currently cachable,
    // so leave the slot in an uncachable state.
    if (!specificFunction)
        slot.setNewProperty(this, offset);
    return true;
}

inline bool JSObject::putOwnDataProperty(JSGlobalData& globalData, const Identifier& propertyName, JSValue value, PutPropertySlot& slot)
{
    ASSERT(value);
    ASSERT(!Heap::heap(value) || Heap::heap(value) == Heap::heap(this));
    ASSERT(!structure()->hasGetterSetterProperties());

    return putDirectInternal<PutModePut>(globalData, propertyName, value, 0, slot, getJSFunction(value));
}

inline void JSObject::putDirect(JSGlobalData& globalData, const Identifier& propertyName, JSValue value, unsigned attributes)
{
    PutPropertySlot slot;
    putDirectInternal<PutModeDefineOwnProperty>(globalData, propertyName, value, attributes, slot, getJSFunction(value));
}

inline void JSObject::putDirect(JSGlobalData& globalData, const Identifier& propertyName, JSValue value, PutPropertySlot& slot)
{
    putDirectInternal<PutModeDefineOwnProperty>(globalData, propertyName, value, 0, slot, getJSFunction(value));
}

inline void JSObject::putDirectWithoutTransition(JSGlobalData& globalData, const Identifier& propertyName, JSValue value, unsigned attributes)
{
    size_t currentCapacity = structure()->propertyStorageCapacity();
    size_t offset = structure()->addPropertyWithoutTransition(globalData, propertyName, attributes, getJSFunction(value));
    if (currentCapacity != structure()->propertyStorageCapacity())
        allocatePropertyStorage(globalData, currentCapacity, structure()->propertyStorageCapacity());
    putDirectOffset(globalData, offset, value);
}

inline void JSObject::transitionTo(JSGlobalData& globalData, Structure* newStructure)
{
    if (structure()->propertyStorageCapacity() != newStructure->propertyStorageCapacity())
        allocatePropertyStorage(globalData, structure()->propertyStorageCapacity(), newStructure->propertyStorageCapacity());
    setStructure(globalData, newStructure);
}

inline JSValue JSObject::toPrimitive(ExecState* exec, PreferredPrimitiveType preferredType) const
{
    return methodTable()->defaultValue(this, exec, preferredType);
}

inline JSValue JSValue::get(ExecState* exec, const Identifier& propertyName) const
{
    PropertySlot slot(asValue());
    return get(exec, propertyName, slot);
}

inline JSValue JSValue::get(ExecState* exec, const Identifier& propertyName, PropertySlot& slot) const
{
    if (UNLIKELY(!isCell())) {
        JSObject* prototype = synthesizePrototype(exec);
        if (propertyName == exec->propertyNames().underscoreProto)
            return prototype;
        if (!prototype->getPropertySlot(exec, propertyName, slot))
            return jsUndefined();
        return slot.getValue(exec, propertyName);
    }
    JSCell* cell = asCell();
    while (true) {
        if (cell->fastGetOwnPropertySlot(exec, propertyName, slot))
            return slot.getValue(exec, propertyName);
        JSValue prototype = asObject(cell)->prototype();
        if (!prototype.isObject())
            return jsUndefined();
        cell = asObject(prototype);
    }
}

inline JSValue JSValue::get(ExecState* exec, unsigned propertyName) const
{
    PropertySlot slot(asValue());
    return get(exec, propertyName, slot);
}

inline JSValue JSValue::get(ExecState* exec, unsigned propertyName, PropertySlot& slot) const
{
    if (UNLIKELY(!isCell())) {
        JSObject* prototype = synthesizePrototype(exec);
        if (!prototype->getPropertySlot(exec, propertyName, slot))
            return jsUndefined();
        return slot.getValue(exec, propertyName);
    }
    JSCell* cell = const_cast<JSCell*>(asCell());
    while (true) {
        if (cell->methodTable()->getOwnPropertySlotByIndex(cell, exec, propertyName, slot))
            return slot.getValue(exec, propertyName);
        JSValue prototype = asObject(cell)->prototype();
        if (!prototype.isObject())
            return jsUndefined();
        cell = prototype.asCell();
    }
}

inline void JSValue::put(ExecState* exec, const Identifier& propertyName, JSValue value, PutPropertySlot& slot)
{
    if (UNLIKELY(!isCell())) {
        JSObject* thisObject = synthesizeObject(exec);
        thisObject->methodTable()->put(thisObject, exec, propertyName, value, slot);
        return;
    }
    asCell()->methodTable()->put(asCell(), exec, propertyName, value, slot);
}

inline void JSValue::put(ExecState* exec, unsigned propertyName, JSValue value)
{
    if (UNLIKELY(!isCell())) {
        JSObject* thisObject = synthesizeObject(exec);
        thisObject->methodTable()->putByIndex(thisObject, exec, propertyName, value);
        return;
    }
    asCell()->methodTable()->putByIndex(asCell(), exec, propertyName, value);
}

// --- JSValue inlines ----------------------------

ALWAYS_INLINE JSObject* Register::function() const
{
    if (!jsValue())
        return 0;
    return asObject(jsValue());
}

ALWAYS_INLINE Register Register::withCallee(JSObject* callee)
{
    Register r;
    r = JSValue(callee);
    return r;
}

} // namespace JSC

#endif // JSObject_h
