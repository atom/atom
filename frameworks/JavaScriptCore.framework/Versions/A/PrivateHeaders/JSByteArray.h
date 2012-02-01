/*
 * Copyright (C) 2009 Apple Inc. All Rights Reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef JSByteArray_h
#define JSByteArray_h

#include "JSObject.h"

#include <wtf/ByteArray.h>

namespace JSC {

    class JSByteArray : public JSNonFinalObject {
        friend class JSGlobalData;
    public:
        typedef JSNonFinalObject Base;

        bool canAccessIndex(unsigned i) { return i < m_storage->length(); }
        JSValue getIndex(ExecState*, unsigned i)
        {
            ASSERT(canAccessIndex(i));
            return jsNumber(m_storage->data()[i]);
        }

        void setIndex(unsigned i, int value)
        {
            ASSERT(canAccessIndex(i));
            if (value & ~0xFF) {
                if (value < 0)
                    value = 0;
                else
                    value = 255;
            }
            m_storage->data()[i] = static_cast<unsigned char>(value);
        }
        
        void setIndex(unsigned i, double value)
        {
            ASSERT(canAccessIndex(i));
            if (!(value > 0)) // Clamp NaN to 0
                value = 0;
            else if (value > 255)
                value = 255;
            m_storage->data()[i] = static_cast<unsigned char>(value + 0.5);
        }
        
        void setIndex(ExecState* exec, unsigned i, JSValue value)
        {
            double byteValue = value.toNumber(exec);
            if (exec->hadException())
                return;
            if (canAccessIndex(i))
                setIndex(i, byteValue);
        }

    private:
        JS_EXPORT_PRIVATE JSByteArray(ExecState*, Structure*, ByteArray* storage);
        
    public:
        static JSByteArray* create(ExecState* exec, Structure* structure, ByteArray* storage)
        {
            JSByteArray* array = new (NotNull, allocateCell<JSByteArray>(*exec->heap())) JSByteArray(exec, structure, storage);
            array->finishCreation(exec);
            return array;
        }

        JS_EXPORT_PRIVATE static Structure* createStructure(JSGlobalData&, JSGlobalObject*, JSValue prototype, const JSC::ClassInfo* = &s_info);

        JS_EXPORT_PRIVATE static bool getOwnPropertySlot(JSC::JSCell*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::PropertySlot&);
        JS_EXPORT_PRIVATE static bool getOwnPropertySlotByIndex(JSC::JSCell*, JSC::ExecState*, unsigned propertyName, JSC::PropertySlot&);
        JS_EXPORT_PRIVATE static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);
        JS_EXPORT_PRIVATE static void put(JSC::JSCell*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSValue, JSC::PutPropertySlot&);
        JS_EXPORT_PRIVATE static void putByIndex(JSC::JSCell*, JSC::ExecState*, unsigned propertyName, JSC::JSValue);

        JS_EXPORT_PRIVATE static void getOwnPropertyNames(JSC::JSObject*, JSC::ExecState*, JSC::PropertyNameArray&, EnumerationMode);

        static JS_EXPORTDATA const ClassInfo s_info;
        
        size_t length() const { return m_storage->length(); }

        WTF::ByteArray* storage() const { return m_storage.get(); }

        ~JSByteArray();
        JS_EXPORT_PRIVATE static void destroy(JSCell*);

        static size_t offsetOfStorage() { return OBJECT_OFFSETOF(JSByteArray, m_storage); }

    protected:
        static const unsigned StructureFlags = OverridesGetOwnPropertySlot | OverridesGetPropertyNames | JSObject::StructureFlags;

        void finishCreation(ExecState* exec)
        {
            Base::finishCreation(exec->globalData());
            putDirect(exec->globalData(), exec->globalData().propertyNames->length, jsNumber(m_storage->length()), ReadOnly | DontDelete);
        }

    private:
        RefPtr<WTF::ByteArray> m_storage;
    };
    
    JSByteArray* asByteArray(JSValue value);
    inline JSByteArray* asByteArray(JSValue value)
    {
        return static_cast<JSByteArray*>(value.asCell());
    }

    inline bool isJSByteArray(JSValue v) { return v.isCell() && v.asCell()->classInfo() == &JSByteArray::s_info; }

} // namespace JSC

#endif // JSByteArray_h
