/*
 * Copyright (C) 2003, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef KJS_RUNTIME_OBJECT_H
#define KJS_RUNTIME_OBJECT_H

#include "BridgeJSC.h"
#include <runtime/JSGlobalObject.h>

namespace JSC {
namespace Bindings {

class RuntimeObject : public JSNonFinalObject {
public:
    typedef JSNonFinalObject Base;

    static RuntimeObject* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure, PassRefPtr<Instance> instance)
    {
        RuntimeObject* object = new (NotNull, allocateCell<RuntimeObject>(*exec->heap())) RuntimeObject(exec, globalObject, structure, instance);
        object->finishCreation(globalObject);
        return object;
    }

    static void destroy(JSCell*);

    static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier& propertyName, PropertySlot&);
    static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier& propertyName, PropertyDescriptor&);
    static void put(JSCell*, ExecState*, const Identifier& propertyName, JSValue, PutPropertySlot&);
    static bool deleteProperty(JSCell*, ExecState*, const Identifier& propertyName);
    static JSValue defaultValue(const JSObject*, ExecState*, PreferredPrimitiveType);
    static CallType getCallData(JSCell*, CallData&);
    static ConstructType getConstructData(JSCell*, ConstructData&);

    static void getOwnPropertyNames(JSObject*, ExecState*, PropertyNameArray&, EnumerationMode);

    void invalidate();

    Instance* getInternalInstance() const { return m_instance.get(); }

    static JSObject* throwInvalidAccessError(ExecState*);

    static const ClassInfo s_info;

    static ObjectPrototype* createPrototype(ExecState*, JSGlobalObject* globalObject)
    {
        return globalObject->objectPrototype();
    }

    static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
    {
        return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
    }

protected:
    RuntimeObject(ExecState*, JSGlobalObject*, Structure*, PassRefPtr<Instance>);
    void finishCreation(JSGlobalObject*);
    static const unsigned StructureFlags = OverridesGetOwnPropertySlot | OverridesGetPropertyNames | Base::StructureFlags;

private:
    static JSValue fallbackObjectGetter(ExecState*, JSValue, const Identifier&);
    static JSValue fieldGetter(ExecState*, JSValue, const Identifier&);
    static JSValue methodGetter(ExecState*, JSValue, const Identifier&);

    RefPtr<Instance> m_instance;
};
    
}
}

#endif
