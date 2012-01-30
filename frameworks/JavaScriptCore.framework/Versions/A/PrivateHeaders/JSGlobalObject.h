/*
 *  Copyright (C) 2007 Eric Seidel <eric@webkit.org>
 *  Copyright (C) 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef JSGlobalObject_h
#define JSGlobalObject_h

#include "JSArray.h"
#include "JSGlobalData.h"
#include "JSGlobalThis.h"
#include "JSVariableObject.h"
#include "JSWeakObjectMapRefInternal.h"
#include "NumberPrototype.h"
#include "StringPrototype.h"
#include "StructureChain.h"
#include <wtf/HashSet.h>
#include <wtf/OwnPtr.h>
#include <wtf/RandomNumber.h>

namespace JSC {

    class ArrayPrototype;
    class BooleanPrototype;
    class DatePrototype;
    class Debugger;
    class ErrorConstructor;
    class FunctionPrototype;
    class GetterSetter;
    class GlobalCodeBlock;
    class NativeErrorConstructor;
    class ProgramCodeBlock;
    class RegExpConstructor;
    class RegExpPrototype;
    class RegisterFile;

    struct ActivationStackNode;
    struct HashTable;

    typedef Vector<ExecState*, 16> ExecStateStack;
    
    struct GlobalObjectMethodTable {
        typedef bool (*SupportsProfilingFunctionPtr)(const JSGlobalObject*); 
        SupportsProfilingFunctionPtr supportsProfiling;

        typedef bool (*SupportsRichSourceInfoFunctionPtr)(const JSGlobalObject*);
        SupportsRichSourceInfoFunctionPtr supportsRichSourceInfo;

        typedef bool (*ShouldInterruptScriptFunctionPtr)(const JSGlobalObject*);
        ShouldInterruptScriptFunctionPtr shouldInterruptScript;
    };

    class JSGlobalObject : public JSVariableObject {
    private:
        typedef HashSet<RefPtr<OpaqueJSWeakObjectMap> > WeakMapSet;

        struct JSGlobalObjectRareData {
            JSGlobalObjectRareData()
                : profileGroup(0)
            {
            }

            WeakMapSet weakMaps;
            unsigned profileGroup;
        };

    protected:

        RefPtr<JSGlobalData> m_globalData;

        size_t m_registerArraySize;
        Register m_globalCallFrame[RegisterFile::CallFrameHeaderSize];

        WriteBarrier<ScopeChainNode> m_globalScopeChain;
        WriteBarrier<JSObject> m_methodCallDummy;

        WriteBarrier<RegExpConstructor> m_regExpConstructor;
        WriteBarrier<ErrorConstructor> m_errorConstructor;
        WriteBarrier<NativeErrorConstructor> m_evalErrorConstructor;
        WriteBarrier<NativeErrorConstructor> m_rangeErrorConstructor;
        WriteBarrier<NativeErrorConstructor> m_referenceErrorConstructor;
        WriteBarrier<NativeErrorConstructor> m_syntaxErrorConstructor;
        WriteBarrier<NativeErrorConstructor> m_typeErrorConstructor;
        WriteBarrier<NativeErrorConstructor> m_URIErrorConstructor;

        WriteBarrier<JSFunction> m_evalFunction;
        WriteBarrier<JSFunction> m_callFunction;
        WriteBarrier<JSFunction> m_applyFunction;
        WriteBarrier<GetterSetter> m_throwTypeErrorGetterSetter;

        WriteBarrier<ObjectPrototype> m_objectPrototype;
        WriteBarrier<FunctionPrototype> m_functionPrototype;
        WriteBarrier<ArrayPrototype> m_arrayPrototype;
        WriteBarrier<BooleanPrototype> m_booleanPrototype;
        WriteBarrier<StringPrototype> m_stringPrototype;
        WriteBarrier<NumberPrototype> m_numberPrototype;
        WriteBarrier<DatePrototype> m_datePrototype;
        WriteBarrier<RegExpPrototype> m_regExpPrototype;

        WriteBarrier<Structure> m_argumentsStructure;
        WriteBarrier<Structure> m_arrayStructure;
        WriteBarrier<Structure> m_booleanObjectStructure;
        WriteBarrier<Structure> m_callbackConstructorStructure;
        WriteBarrier<Structure> m_callbackFunctionStructure;
        WriteBarrier<Structure> m_callbackObjectStructure;
        WriteBarrier<Structure> m_dateStructure;
        WriteBarrier<Structure> m_emptyObjectStructure;
        WriteBarrier<Structure> m_nullPrototypeObjectStructure;
        WriteBarrier<Structure> m_errorStructure;
        WriteBarrier<Structure> m_functionStructure;
        WriteBarrier<Structure> m_boundFunctionStructure;
        WriteBarrier<Structure> m_namedFunctionStructure;
        size_t m_functionNameOffset;
        WriteBarrier<Structure> m_numberObjectStructure;
        WriteBarrier<Structure> m_regExpMatchesArrayStructure;
        WriteBarrier<Structure> m_regExpStructure;
        WriteBarrier<Structure> m_stringObjectStructure;
        WriteBarrier<Structure> m_internalFunctionStructure;

        Debugger* m_debugger;

        OwnPtr<JSGlobalObjectRareData> m_rareData;

        WeakRandom m_weakRandom;

        SymbolTable m_symbolTable;

        bool m_evalEnabled;

        static JS_EXPORTDATA const GlobalObjectMethodTable s_globalObjectMethodTable;
        const GlobalObjectMethodTable* m_globalObjectMethodTable;

        void createRareDataIfNeeded()
        {
            if (m_rareData)
                return;
            m_rareData = adoptPtr(new JSGlobalObjectRareData);
            Heap::heap(this)->addFinalizer(this, clearRareData);
        }
        
    public:
        typedef JSVariableObject Base;

        static JSGlobalObject* create(JSGlobalData& globalData, Structure* structure)
        {
            JSGlobalObject* globalObject = new (NotNull, allocateCell<JSGlobalObject>(globalData.heap)) JSGlobalObject(globalData, structure);
            globalObject->finishCreation(globalData);
            return globalObject;
        }

        static JS_EXPORTDATA const ClassInfo s_info;

    protected:
        explicit JSGlobalObject(JSGlobalData& globalData, Structure* structure, const GlobalObjectMethodTable* globalObjectMethodTable = 0)
            : JSVariableObject(globalData, structure, &m_symbolTable, 0)
            , m_registerArraySize(0)
            , m_globalScopeChain()
            , m_weakRandom(static_cast<unsigned>(randomNumber() * (std::numeric_limits<unsigned>::max() + 1.0)))
            , m_evalEnabled(true)
            , m_globalObjectMethodTable(globalObjectMethodTable ? globalObjectMethodTable : &s_globalObjectMethodTable)
        {
        }

        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData);
            structure()->setGlobalObject(globalData, this);
            init(this);
        }

        void finishCreation(JSGlobalData& globalData, JSGlobalThis* thisValue)
        {
            Base::finishCreation(globalData);
            structure()->setGlobalObject(globalData, this);
            init(thisValue);
        }

    public:
        JS_EXPORT_PRIVATE ~JSGlobalObject();
        JS_EXPORT_PRIVATE static void destroy(JSCell*);

        JS_EXPORT_PRIVATE static void visitChildren(JSCell*, SlotVisitor&);

        JS_EXPORT_PRIVATE static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier&, PropertySlot&);
        JS_EXPORT_PRIVATE static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);
        bool hasOwnPropertyForWrite(ExecState*, const Identifier&);
        JS_EXPORT_PRIVATE static void put(JSCell*, ExecState*, const Identifier&, JSValue, PutPropertySlot&);

        JS_EXPORT_PRIVATE static void putDirectVirtual(JSObject*, ExecState*, const Identifier& propertyName, JSValue, unsigned attributes);

        JS_EXPORT_PRIVATE static void defineGetter(JSObject*, ExecState*, const Identifier& propertyName, JSObject* getterFunc, unsigned attributes);
        JS_EXPORT_PRIVATE static void defineSetter(JSObject*, ExecState*, const Identifier& propertyName, JSObject* setterFunc, unsigned attributes);

        // We use this in the code generator as we perform symbol table
        // lookups prior to initializing the properties
        bool symbolTableHasProperty(const Identifier& propertyName);

        // The following accessors return pristine values, even if a script 
        // replaces the global object's associated property.

        RegExpConstructor* regExpConstructor() const { return m_regExpConstructor.get(); }

        ErrorConstructor* errorConstructor() const { return m_errorConstructor.get(); }
        NativeErrorConstructor* evalErrorConstructor() const { return m_evalErrorConstructor.get(); }
        NativeErrorConstructor* rangeErrorConstructor() const { return m_rangeErrorConstructor.get(); }
        NativeErrorConstructor* referenceErrorConstructor() const { return m_referenceErrorConstructor.get(); }
        NativeErrorConstructor* syntaxErrorConstructor() const { return m_syntaxErrorConstructor.get(); }
        NativeErrorConstructor* typeErrorConstructor() const { return m_typeErrorConstructor.get(); }
        NativeErrorConstructor* URIErrorConstructor() const { return m_URIErrorConstructor.get(); }

        JSFunction* evalFunction() const { return m_evalFunction.get(); }
        JSFunction* callFunction() const { return m_callFunction.get(); }
        JSFunction* applyFunction() const { return m_applyFunction.get(); }
        GetterSetter* throwTypeErrorGetterSetter(ExecState* exec)
        {
            if (!m_throwTypeErrorGetterSetter)
                createThrowTypeError(exec);
            return m_throwTypeErrorGetterSetter.get();
        }

        ObjectPrototype* objectPrototype() const { return m_objectPrototype.get(); }
        FunctionPrototype* functionPrototype() const { return m_functionPrototype.get(); }
        ArrayPrototype* arrayPrototype() const { return m_arrayPrototype.get(); }
        BooleanPrototype* booleanPrototype() const { return m_booleanPrototype.get(); }
        StringPrototype* stringPrototype() const { return m_stringPrototype.get(); }
        NumberPrototype* numberPrototype() const { return m_numberPrototype.get(); }
        DatePrototype* datePrototype() const { return m_datePrototype.get(); }
        RegExpPrototype* regExpPrototype() const { return m_regExpPrototype.get(); }

        JSObject* methodCallDummy() const { return m_methodCallDummy.get(); }

        Structure* argumentsStructure() const { return m_argumentsStructure.get(); }
        Structure* arrayStructure() const { return m_arrayStructure.get(); }
        Structure* booleanObjectStructure() const { return m_booleanObjectStructure.get(); }
        Structure* callbackConstructorStructure() const { return m_callbackConstructorStructure.get(); }
        Structure* callbackFunctionStructure() const { return m_callbackFunctionStructure.get(); }
        Structure* callbackObjectStructure() const { return m_callbackObjectStructure.get(); }
        Structure* dateStructure() const { return m_dateStructure.get(); }
        Structure* emptyObjectStructure() const { return m_emptyObjectStructure.get(); }
        Structure* nullPrototypeObjectStructure() const { return m_nullPrototypeObjectStructure.get(); }
        Structure* errorStructure() const { return m_errorStructure.get(); }
        Structure* functionStructure() const { return m_functionStructure.get(); }
        Structure* boundFunctionStructure() const { return m_boundFunctionStructure.get(); }
        Structure* namedFunctionStructure() const { return m_namedFunctionStructure.get(); }
        size_t functionNameOffset() const { return m_functionNameOffset; }
        Structure* numberObjectStructure() const { return m_numberObjectStructure.get(); }
        Structure* internalFunctionStructure() const { return m_internalFunctionStructure.get(); }
        Structure* regExpMatchesArrayStructure() const { return m_regExpMatchesArrayStructure.get(); }
        Structure* regExpStructure() const { return m_regExpStructure.get(); }
        Structure* stringObjectStructure() const { return m_stringObjectStructure.get(); }

        void setProfileGroup(unsigned value) { createRareDataIfNeeded(); m_rareData->profileGroup = value; }
        unsigned profileGroup() const
        { 
            if (!m_rareData)
                return 0;
            return m_rareData->profileGroup;
        }

        Debugger* debugger() const { return m_debugger; }
        void setDebugger(Debugger* debugger) { m_debugger = debugger; }

        const GlobalObjectMethodTable* globalObjectMethodTable() const { return m_globalObjectMethodTable; }

        static bool supportsProfiling(const JSGlobalObject*) { return false; }
        static bool supportsRichSourceInfo(const JSGlobalObject*) { return true; }

        ScopeChainNode* globalScopeChain() { return m_globalScopeChain.get(); }

        JS_EXPORT_PRIVATE ExecState* globalExec();

        static bool shouldInterruptScript(const JSGlobalObject*) { return true; }

        bool isDynamicScope(bool& requiresDynamicChecks) const;

        void setEvalEnabled(bool enabled) { m_evalEnabled = enabled; }
        bool evalEnabled() { return m_evalEnabled; }

        void resizeRegisters(size_t newSize);

        void resetPrototype(JSGlobalData&, JSValue prototype);

        JSGlobalData& globalData() const { return *m_globalData.get(); }

        static Structure* createStructure(JSGlobalData& globalData, JSValue prototype)
        {
            return Structure::create(globalData, 0, prototype, TypeInfo(GlobalObjectType, StructureFlags), &s_info);
        }

        void registerWeakMap(OpaqueJSWeakObjectMap* map)
        {
            createRareDataIfNeeded();
            m_rareData->weakMaps.add(map);
        }

        void unregisterWeakMap(OpaqueJSWeakObjectMap* map)
        {
            if (m_rareData)
                m_rareData->weakMaps.remove(map);
        }

        double weakRandomNumber() { return m_weakRandom.get(); }
    protected:

        static const unsigned StructureFlags = OverridesGetOwnPropertySlot | OverridesVisitChildren | OverridesGetPropertyNames | JSVariableObject::StructureFlags;

        struct GlobalPropertyInfo {
            GlobalPropertyInfo(const Identifier& i, JSValue v, unsigned a)
                : identifier(i)
                , value(v)
                , attributes(a)
            {
            }

            const Identifier identifier;
            JSValue value;
            unsigned attributes;
        };
        JS_EXPORT_PRIVATE void addStaticGlobals(GlobalPropertyInfo*, int count);

    private:
        // FIXME: Fold reset into init.
        JS_EXPORT_PRIVATE void init(JSObject* thisValue);
        void reset(JSValue prototype);

        void createThrowTypeError(ExecState*);

        void setRegisters(WriteBarrier<Unknown>* registers, PassOwnArrayPtr<WriteBarrier<Unknown> > registerArray, size_t count);
        JS_EXPORT_PRIVATE static void clearRareData(JSCell*);
    };

    JSGlobalObject* asGlobalObject(JSValue);

    inline JSGlobalObject* asGlobalObject(JSValue value)
    {
        ASSERT(asObject(value)->isGlobalObject());
        return static_cast<JSGlobalObject*>(asObject(value));
    }

    inline void JSGlobalObject::setRegisters(WriteBarrier<Unknown>* registers, PassOwnArrayPtr<WriteBarrier<Unknown> > registerArray, size_t count)
    {
        JSVariableObject::setRegisters(registers, registerArray);
        m_registerArraySize = count;
    }

    inline bool JSGlobalObject::hasOwnPropertyForWrite(ExecState* exec, const Identifier& propertyName)
    {
        PropertySlot slot;
        if (JSVariableObject::getOwnPropertySlot(this, exec, propertyName, slot))
            return true;
        bool slotIsWriteable;
        return symbolTableGet(propertyName, slot, slotIsWriteable);
    }

    inline bool JSGlobalObject::symbolTableHasProperty(const Identifier& propertyName)
    {
        SymbolTableEntry entry = symbolTable().inlineGet(propertyName.impl());
        return !entry.isNull();
    }

    inline JSValue Structure::prototypeForLookup(ExecState* exec) const
    {
        if (isObject())
            return m_prototype.get();

        ASSERT(typeInfo().type() == StringType);
        return exec->lexicalGlobalObject()->stringPrototype();
    }

    inline StructureChain* Structure::prototypeChain(ExecState* exec) const
    {
        // We cache our prototype chain so our clients can share it.
        if (!isValid(exec, m_cachedPrototypeChain.get())) {
            JSValue prototype = prototypeForLookup(exec);
            m_cachedPrototypeChain.set(exec->globalData(), this, StructureChain::create(exec->globalData(), prototype.isNull() ? 0 : asObject(prototype)->structure()));
        }
        return m_cachedPrototypeChain.get();
    }

    inline bool Structure::isValid(ExecState* exec, StructureChain* cachedPrototypeChain) const
    {
        if (!cachedPrototypeChain)
            return false;

        JSValue prototype = prototypeForLookup(exec);
        WriteBarrier<Structure>* cachedStructure = cachedPrototypeChain->head();
        while(*cachedStructure && !prototype.isNull()) {
            if (asObject(prototype)->structure() != cachedStructure->get())
                return false;
            ++cachedStructure;
            prototype = asObject(prototype)->prototype();
        }
        return prototype.isNull() && !*cachedStructure;
    }

    inline JSGlobalObject* ExecState::dynamicGlobalObject()
    {
        if (this == lexicalGlobalObject()->globalExec())
            return lexicalGlobalObject();

        // For any ExecState that's not a globalExec, the 
        // dynamic global object must be set since code is running
        ASSERT(globalData().dynamicGlobalObject);
        return globalData().dynamicGlobalObject;
    }

    inline JSObject* constructEmptyObject(ExecState* exec, JSGlobalObject* globalObject)
    {
        return constructEmptyObject(exec, globalObject->emptyObjectStructure());
    }

    inline JSObject* constructEmptyObject(ExecState* exec)
    {
        return constructEmptyObject(exec, exec->lexicalGlobalObject());
    }

    inline JSArray* constructEmptyArray(ExecState* exec, JSGlobalObject* globalObject, unsigned initialLength = 0)
    {
        return JSArray::create(exec->globalData(), globalObject->arrayStructure(), initialLength);
    }

    inline JSArray* constructEmptyArray(ExecState* exec, unsigned initialLength = 0)
    {
        return constructEmptyArray(exec, exec->lexicalGlobalObject(), initialLength);
    }

    inline JSArray* constructArray(ExecState* exec, JSGlobalObject* globalObject, const ArgList& values)
    {
        JSGlobalData& globalData = exec->globalData();
        unsigned length = values.size();
        JSArray* array = JSArray::tryCreateUninitialized(globalData, globalObject->arrayStructure(), length);

        // FIXME: we should probably throw an out of memory error here, but
        // when making this change we should check that all clients of this
        // function will correctly handle an exception being thrown from here.
        if (!array)
            CRASH();

        for (unsigned i = 0; i < length; ++i)
            array->initializeIndex(globalData, i, values.at(i));
        array->completeInitialization(length);
        return array;
    }

    inline JSArray* constructArray(ExecState* exec, const ArgList& values)
    {
        return constructArray(exec, exec->lexicalGlobalObject(), values);
    }

    inline JSArray* constructArray(ExecState* exec, JSGlobalObject* globalObject, const JSValue* values, unsigned length)
    {
        JSGlobalData& globalData = exec->globalData();
        JSArray* array = JSArray::tryCreateUninitialized(globalData, globalObject->arrayStructure(), length);

        // FIXME: we should probably throw an out of memory error here, but
        // when making this change we should check that all clients of this
        // function will correctly handle an exception being thrown from here.
        if (!array)
            CRASH();

        for (unsigned i = 0; i < length; ++i)
            array->initializeIndex(globalData, i, values[i]);
        array->completeInitialization(length);
        return array;
    }

    inline JSArray* constructArray(ExecState* exec, const JSValue* values, unsigned length)
    {
        return constructArray(exec, exec->lexicalGlobalObject(), values, length);
    }

    class DynamicGlobalObjectScope {
        WTF_MAKE_NONCOPYABLE(DynamicGlobalObjectScope);
    public:
        JS_EXPORT_PRIVATE DynamicGlobalObjectScope(JSGlobalData&, JSGlobalObject*);

        ~DynamicGlobalObjectScope()
        {
            m_dynamicGlobalObjectSlot = m_savedDynamicGlobalObject;
        }

    private:
        JSGlobalObject*& m_dynamicGlobalObjectSlot;
        JSGlobalObject* m_savedDynamicGlobalObject;
    };

    inline bool JSGlobalObject::isDynamicScope(bool&) const
    {
        return true;
    }

} // namespace JSC

#endif // JSGlobalObject_h
