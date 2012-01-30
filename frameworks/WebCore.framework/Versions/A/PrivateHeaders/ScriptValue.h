/*
 * Copyright (c) 2008, 2011 Google Inc. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ScriptValue_h
#define ScriptValue_h

#include "JSDOMBinding.h"
#include "PlatformString.h"
#include "SerializedScriptValue.h"
#include "ScriptState.h"
#include <heap/Strong.h>
#include <heap/StrongInlines.h>
#include <runtime/JSValue.h>
#include <wtf/PassRefPtr.h>

namespace WebCore {

class InspectorValue;
class SerializedScriptValue;

class ScriptValue {
public:
    ScriptValue() { }
    ScriptValue(JSC::JSGlobalData& globalData, JSC::JSValue value) : m_value(globalData, value) {}
    virtual ~ScriptValue() {}

    JSC::JSValue jsValue() const { return m_value.get(); }
    bool getString(ScriptState*, String& result) const;
    String toString(ScriptState*) const;
    bool isEqual(ScriptState*, const ScriptValue&) const;
    bool isNull() const;
    bool isUndefined() const;
    bool isObject() const;
    bool isFunction() const;
    bool hasNoValue() const { return !m_value; }

    bool operator==(const ScriptValue& other) const { return m_value == other.m_value; }

    PassRefPtr<SerializedScriptValue> serialize(ScriptState*, SerializationErrorMode = Throwing);
    static ScriptValue deserialize(ScriptState*, SerializedScriptValue*, SerializationErrorMode = Throwing);

    static ScriptValue undefined();

#if ENABLE(INSPECTOR)
    PassRefPtr<InspectorValue> toInspectorValue(ScriptState*) const;
#endif

private:
    JSC::Strong<JSC::Unknown> m_value;
};

} // namespace WebCore

#endif // ScriptValue_h
