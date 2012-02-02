/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef APICast_h
#define APICast_h

#include "JSAPIValueWrapper.h"
#include "JSGlobalObject.h"
#include "JSValue.h"
#include <wtf/UnusedParam.h>

namespace JSC {
    class ExecState;
    class PropertyNameArray;
    class JSGlobalData;
    class JSObject;
    class JSValue;
}

typedef const struct OpaqueJSContextGroup* JSContextGroupRef;
typedef const struct OpaqueJSContext* JSContextRef;
typedef struct OpaqueJSContext* JSGlobalContextRef;
typedef struct OpaqueJSPropertyNameAccumulator* JSPropertyNameAccumulatorRef;
typedef const struct OpaqueJSValue* JSValueRef;
typedef struct OpaqueJSValue* JSObjectRef;

/* Opaque typing convenience methods */

inline JSC::ExecState* toJS(JSContextRef c)
{
    ASSERT(c);
    return reinterpret_cast<JSC::ExecState*>(const_cast<OpaqueJSContext*>(c));
}

inline JSC::ExecState* toJS(JSGlobalContextRef c)
{
    ASSERT(c);
    return reinterpret_cast<JSC::ExecState*>(c);
}

inline JSC::JSValue toJS(JSC::ExecState* exec, JSValueRef v)
{
    ASSERT_UNUSED(exec, exec);
    ASSERT(v);
#if USE(JSVALUE32_64)
    JSC::JSCell* jsCell = reinterpret_cast<JSC::JSCell*>(const_cast<OpaqueJSValue*>(v));
    if (!jsCell)
        return JSC::JSValue();
    if (jsCell->isAPIValueWrapper())
        return static_cast<JSC::JSAPIValueWrapper*>(jsCell)->value();
    return jsCell;
#else
    return JSC::JSValue::decode(reinterpret_cast<JSC::EncodedJSValue>(const_cast<OpaqueJSValue*>(v)));
#endif
}

inline JSC::JSValue toJSForGC(JSC::ExecState* exec, JSValueRef v)
{
    ASSERT_UNUSED(exec, exec);
    ASSERT(v);
#if USE(JSVALUE32_64)
    JSC::JSCell* jsCell = reinterpret_cast<JSC::JSCell*>(const_cast<OpaqueJSValue*>(v));
    if (!jsCell)
        return JSC::JSValue();
    return jsCell;
#else
    return JSC::JSValue::decode(reinterpret_cast<JSC::EncodedJSValue>(const_cast<OpaqueJSValue*>(v)));
#endif
}

inline JSC::JSObject* toJS(JSObjectRef o)
{
    return reinterpret_cast<JSC::JSObject*>(o);
}

inline JSC::PropertyNameArray* toJS(JSPropertyNameAccumulatorRef a)
{
    return reinterpret_cast<JSC::PropertyNameArray*>(a);
}

inline JSC::JSGlobalData* toJS(JSContextGroupRef g)
{
    return reinterpret_cast<JSC::JSGlobalData*>(const_cast<OpaqueJSContextGroup*>(g));
}

inline JSValueRef toRef(JSC::ExecState* exec, JSC::JSValue v)
{
#if USE(JSVALUE32_64)
    if (!v)
        return 0;
    if (!v.isCell())
        return reinterpret_cast<JSValueRef>(JSC::jsAPIValueWrapper(exec, v).asCell());
    return reinterpret_cast<JSValueRef>(v.asCell());
#else
    UNUSED_PARAM(exec);
    return reinterpret_cast<JSValueRef>(JSC::JSValue::encode(v));
#endif
}

inline JSObjectRef toRef(JSC::JSObject* o)
{
    return reinterpret_cast<JSObjectRef>(o);
}

inline JSObjectRef toRef(const JSC::JSObject* o)
{
    return reinterpret_cast<JSObjectRef>(const_cast<JSC::JSObject*>(o));
}

inline JSContextRef toRef(JSC::ExecState* e)
{
    return reinterpret_cast<JSContextRef>(e);
}

inline JSGlobalContextRef toGlobalRef(JSC::ExecState* e)
{
    ASSERT(e == e->lexicalGlobalObject()->globalExec());
    return reinterpret_cast<JSGlobalContextRef>(e);
}

inline JSPropertyNameAccumulatorRef toRef(JSC::PropertyNameArray* l)
{
    return reinterpret_cast<JSPropertyNameAccumulatorRef>(l);
}

inline JSContextGroupRef toRef(JSC::JSGlobalData* g)
{
    return reinterpret_cast<JSContextGroupRef>(g);
}

#endif // APICast_h
