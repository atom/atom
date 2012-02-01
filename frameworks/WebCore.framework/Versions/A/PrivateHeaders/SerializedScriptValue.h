/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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
 *
 */

#ifndef SerializedScriptValue_h
#define SerializedScriptValue_h

#include <heap/Strong.h>
#include <runtime/JSValue.h>
#include <wtf/Forward.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>

typedef const struct OpaqueJSContext* JSContextRef;
typedef const struct OpaqueJSValue* JSValueRef;

namespace WebCore {

class MessagePort;
typedef Vector<RefPtr<MessagePort>, 1> MessagePortArray;
 
enum SerializationReturnCode {
    SuccessfullyCompleted,
    StackOverflowError,
    InterruptedExecutionError,
    ValidationError,
    ExistingExceptionError,
    UnspecifiedError
};
    
enum SerializationErrorMode { NonThrowing, Throwing };

class SharedBuffer;

class SerializedScriptValue : public RefCounted<SerializedScriptValue> {
public:
    static PassRefPtr<SerializedScriptValue> create(JSC::ExecState*, JSC::JSValue, MessagePortArray*, SerializationErrorMode = Throwing);
    static PassRefPtr<SerializedScriptValue> create(JSContextRef, JSValueRef, MessagePortArray*,  JSValueRef* exception);
    static PassRefPtr<SerializedScriptValue> create(JSContextRef, JSValueRef, JSValueRef* exception);

    static PassRefPtr<SerializedScriptValue> create(const String&);
    static PassRefPtr<SerializedScriptValue> adopt(Vector<uint8_t>& buffer)
    {
        return adoptRef(new SerializedScriptValue(buffer));
    }

    static PassRefPtr<SerializedScriptValue> create();
    static SerializedScriptValue* nullValue();
    static PassRefPtr<SerializedScriptValue> undefinedValue();
    static PassRefPtr<SerializedScriptValue> booleanValue(bool value);

    String toString();
    
    JSC::JSValue deserialize(JSC::ExecState*, JSC::JSGlobalObject*, MessagePortArray*, SerializationErrorMode = Throwing);
    JSValueRef deserialize(JSContextRef, JSValueRef* exception, MessagePortArray*);
    JSValueRef deserialize(JSContextRef, JSValueRef* exception);

    const Vector<uint8_t>& data() { return m_data; }

    ~SerializedScriptValue();

private:
    static void maybeThrowExceptionIfSerializationFailed(JSC::ExecState*, SerializationReturnCode);
    static bool serializationDidCompleteSuccessfully(SerializationReturnCode);
    
    SerializedScriptValue(Vector<unsigned char>&);
    Vector<unsigned char> m_data;
};

}

#endif // SerializedScriptValue_h
