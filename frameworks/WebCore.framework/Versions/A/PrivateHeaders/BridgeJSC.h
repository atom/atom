/*
 * Copyright (C) 2003, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright 2010, The Android Open Source Project
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

#ifndef BridgeJSC_h
#define BridgeJSC_h

#include "Bridge.h"
#include <runtime/JSString.h>
#include <wtf/HashMap.h>
#include <wtf/RefCounted.h>
#include <wtf/Vector.h>

namespace JSC  {

class ArgList;
class Identifier;
class JSGlobalObject;
class PropertyNameArray;
class RuntimeMethod;

namespace Bindings {

class Instance;
class Method;
class RootObject;
class RuntimeObject;

typedef Vector<Method*> MethodList;

class Field {
public:
    virtual JSValue valueFromInstance(ExecState*, const Instance*) const = 0;
    virtual void setValueToInstance(ExecState*, const Instance*, JSValue) const = 0;

    virtual ~Field() { }
};

class Class {
    WTF_MAKE_NONCOPYABLE(Class); WTF_MAKE_FAST_ALLOCATED;
public:
    Class() { }
    virtual MethodList methodsNamed(const Identifier&, Instance*) const = 0;
    virtual Field* fieldNamed(const Identifier&, Instance*) const = 0;
    virtual JSValue fallbackObject(ExecState*, Instance*, const Identifier&) { return jsUndefined(); }

    virtual ~Class() { }
};

typedef void (*KJSDidExecuteFunctionPtr)(ExecState*, JSObject* rootObject);

class Instance : public RefCounted<Instance> {
public:
    Instance(PassRefPtr<RootObject>);

    static void setDidExecuteFunction(KJSDidExecuteFunctionPtr func);
    static KJSDidExecuteFunctionPtr didExecuteFunction();

    // These functions are called before and after the main entry points into
    // the native implementations.  They can be used to establish and cleanup
    // any needed state.
    void begin();
    void end();

    virtual Class* getClass() const = 0;
    JSObject* createRuntimeObject(ExecState*);
    void willInvalidateRuntimeObject();

    // Returns false if the value was not set successfully.
    virtual bool setValueOfUndefinedField(ExecState*, const Identifier&, JSValue) { return false; }

    virtual JSValue getMethod(ExecState* exec, const Identifier& propertyName) = 0;
    virtual JSValue invokeMethod(ExecState*, RuntimeMethod* method) = 0;

    virtual bool supportsInvokeDefaultMethod() const { return false; }
    virtual JSValue invokeDefaultMethod(ExecState*) { return jsUndefined(); }

    virtual bool supportsConstruct() const { return false; }
    virtual JSValue invokeConstruct(ExecState*, const ArgList&) { return JSValue(); }

    virtual void getPropertyNames(ExecState*, PropertyNameArray&) { }

    virtual JSValue defaultValue(ExecState*, PreferredPrimitiveType) const = 0;

    virtual JSValue valueOf(ExecState* exec) const = 0;

    RootObject* rootObject() const;

    virtual ~Instance();

    virtual bool getOwnPropertySlot(JSObject*, ExecState*, const Identifier&, PropertySlot&) { return false; }
    virtual bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&) { return false; }
    virtual void put(JSObject*, ExecState*, const Identifier&, JSValue, PutPropertySlot&) { }

protected:
    virtual void virtualBegin() { }
    virtual void virtualEnd() { }
    virtual RuntimeObject* newRuntimeObject(ExecState*);

    RefPtr<RootObject> m_rootObject;

private:
    Weak<RuntimeObject> m_runtimeObject;
};

class Array {
    WTF_MAKE_NONCOPYABLE(Array);
public:
    Array(PassRefPtr<RootObject>);
    virtual ~Array();

    virtual void setValueAt(ExecState*, unsigned index, JSValue) const = 0;
    virtual JSValue valueAt(ExecState*, unsigned index) const = 0;
    virtual unsigned int getLength() const = 0;

protected:
    RefPtr<RootObject> m_rootObject;
};

const char* signatureForParameters(const ArgList&);

typedef HashMap<RefPtr<StringImpl>, MethodList*> MethodListMap;
typedef HashMap<RefPtr<StringImpl>, Method*> MethodMap;
typedef HashMap<RefPtr<StringImpl>, Field*> FieldMap;

} // namespace Bindings

} // namespace JSC

#endif
