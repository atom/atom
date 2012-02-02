/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef JSString_h
#define JSString_h
#include "CallFrame.h"
#include "CommonIdentifiers.h"
#include "Identifier.h"
#include "PropertyDescriptor.h"
#include "PropertySlot.h"
#include "Structure.h"

namespace JSC {

    class JSString;

    JSString* jsEmptyString(JSGlobalData*);
    JSString* jsEmptyString(ExecState*);
    JSString* jsString(JSGlobalData*, const UString&); // returns empty string if passed null string
    JSString* jsString(ExecState*, const UString&); // returns empty string if passed null string

    JSString* jsSingleCharacterString(JSGlobalData*, UChar);
    JSString* jsSingleCharacterString(ExecState*, UChar);
    JSString* jsSingleCharacterSubstring(ExecState*, const UString&, unsigned offset);
    JSString* jsSubstring(JSGlobalData*, const UString&, unsigned offset, unsigned length);
    JSString* jsSubstring(ExecState*, const UString&, unsigned offset, unsigned length);

    // Non-trivial strings are two or more characters long.
    // These functions are faster than just calling jsString.
    JSString* jsNontrivialString(JSGlobalData*, const UString&);
    JSString* jsNontrivialString(ExecState*, const UString&);
    JSString* jsNontrivialString(JSGlobalData*, const char*);
    JSString* jsNontrivialString(ExecState*, const char*);

    // Should be used for strings that are owned by an object that will
    // likely outlive the JSValue this makes, such as the parse tree or a
    // DOM object that contains a UString
    JSString* jsOwnedString(JSGlobalData*, const UString&); 
    JSString* jsOwnedString(ExecState*, const UString&); 

    JSString* jsStringBuilder(JSGlobalData*);

    class JSString : public JSCell {
    public:
        friend class JIT;
        friend class JSGlobalData;
        friend class SpecializedThunkJIT;
        friend struct ThunkHelpers;
        friend JSString* jsStringBuilder(JSGlobalData*);

        typedef JSCell Base;

        static void destroy(JSCell*);

        class RopeBuilder {
        public:
            RopeBuilder(JSGlobalData& globalData)
                : m_globalData(globalData)
                , m_jsString(jsStringBuilder(&globalData))
                , m_index(0)
            {
            }

            void append(JSString* jsString)
            {
                if (m_index == JSString::s_maxInternalRopeLength)
                    expand();
                m_jsString->m_fibers[m_index++].set(m_globalData, m_jsString, jsString);
                m_jsString->m_length += jsString->m_length;
                m_jsString->m_is8Bit = m_jsString->m_is8Bit && jsString->m_is8Bit;
            }

            JSString* release()
            {
                JSString* tmp = m_jsString;
                m_jsString = 0;
                return tmp;
            }

            unsigned length() { return m_jsString->m_length; }

        private:
            void expand();

            JSGlobalData& m_globalData;
            JSString* m_jsString;
            size_t m_index;
        };

    private:
        JSString(JSGlobalData& globalData, PassRefPtr<StringImpl> value)
            : JSCell(globalData, globalData.stringStructure.get())
            , m_value(value)
        {
        }

        JSString(JSGlobalData& globalData)
            : JSCell(globalData, globalData.stringStructure.get())
        {
        }

        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData);
            m_length = 0;
            m_is8Bit = true;
        }

        void finishCreation(JSGlobalData& globalData, size_t length)
        {
            ASSERT(!m_value.isNull());
            Base::finishCreation(globalData);
            m_length = length;
            m_is8Bit = m_value.impl()->is8Bit();
        }

        void finishCreation(JSGlobalData& globalData, size_t length, size_t cost)
        {
            ASSERT(!m_value.isNull());
            Base::finishCreation(globalData);
            m_length = length;
            m_is8Bit = m_value.impl()->is8Bit();
            Heap::heap(this)->reportExtraMemoryCost(cost);
        }

        void finishCreation(JSGlobalData& globalData, JSString* s1, JSString* s2)
        {
            Base::finishCreation(globalData);
            m_length = s1->length() + s2->length();
            m_is8Bit = (s1->is8Bit() && s2->is8Bit());
            m_fibers[0].set(globalData, this, s1);
            m_fibers[1].set(globalData, this, s2);
        }

        void finishCreation(JSGlobalData& globalData, JSString* s1, JSString* s2, JSString* s3)
        {
            Base::finishCreation(globalData);
            m_length = s1->length() + s2->length() + s3->length();
            m_is8Bit = (s1->is8Bit() && s2->is8Bit() &&  s3->is8Bit());
            m_fibers[0].set(globalData, this, s1);
            m_fibers[1].set(globalData, this, s2);
            m_fibers[2].set(globalData, this, s3);
        }

        static JSString* createNull(JSGlobalData& globalData)
        {
            JSString* newString = new (NotNull, allocateCell<JSString>(globalData.heap)) JSString(globalData);
            newString->finishCreation(globalData);
            return newString;
        }

    public:
        static JSString* create(JSGlobalData& globalData, PassRefPtr<StringImpl> value)
        {
            ASSERT(value);
            size_t length = value->length();
            size_t cost = value->cost();
            JSString* newString = new (NotNull, allocateCell<JSString>(globalData.heap)) JSString(globalData, value);
            newString->finishCreation(globalData, length, cost);
            return newString;
        }
        static JSString* create(JSGlobalData& globalData, JSString* s1, JSString* s2)
        {
            JSString* newString = new (NotNull, allocateCell<JSString>(globalData.heap)) JSString(globalData);
            newString->finishCreation(globalData, s1, s2);
            return newString;
        }
        static JSString* create(JSGlobalData& globalData, JSString* s1, JSString* s2, JSString* s3)
        {
            JSString* newString = new (NotNull, allocateCell<JSString>(globalData.heap)) JSString(globalData);
            newString->finishCreation(globalData, s1, s2, s3);
            return newString;
        }
        static JSString* createHasOtherOwner(JSGlobalData& globalData, PassRefPtr<StringImpl> value)
        {
            ASSERT(value);
            size_t length = value->length();
            JSString* newString = new (NotNull, allocateCell<JSString>(globalData.heap)) JSString(globalData, value);
            newString->finishCreation(globalData, length);
            return newString;
        }

        const UString& value(ExecState* exec) const
        {
            if (isRope())
                resolveRope(exec);
            return m_value;
        }
        const UString& tryGetValue() const
        {
            if (isRope())
                resolveRope(0);
            return m_value;
        }
        unsigned length() { return m_length; }

        JSValue toPrimitive(ExecState*, PreferredPrimitiveType) const;
        JS_EXPORT_PRIVATE bool toBoolean(ExecState*) const;
        bool getPrimitiveNumber(ExecState*, double& number, JSValue&) const;
        JSObject* toObject(ExecState*, JSGlobalObject*) const;
        double toNumber(ExecState*) const;
        
        bool getStringPropertySlot(ExecState*, const Identifier& propertyName, PropertySlot&);
        bool getStringPropertySlot(ExecState*, unsigned propertyName, PropertySlot&);
        bool getStringPropertyDescriptor(ExecState*, const Identifier& propertyName, PropertyDescriptor&);

        bool canGetIndex(unsigned i) { return i < m_length; }
        JSString* getIndex(ExecState*, unsigned);
        JSString* getIndexSlowCase(ExecState*, unsigned);

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue proto)
        {
            return Structure::create(globalData, globalObject, proto, TypeInfo(StringType, OverridesGetOwnPropertySlot), &s_info);
        }

        static size_t offsetOfLength() { return OBJECT_OFFSETOF(JSString, m_length); }
        static size_t offsetOfValue() { return OBJECT_OFFSETOF(JSString, m_value); }

        static JS_EXPORTDATA const ClassInfo s_info;

        static void visitChildren(JSCell*, SlotVisitor&);

    private:
        JS_EXPORT_PRIVATE void resolveRope(ExecState*) const;
        void resolveRopeSlowCase8(LChar*) const;
        void resolveRopeSlowCase(UChar*) const;
        void outOfMemory(ExecState*) const;

        static JSObject* toThisObject(JSCell*, ExecState*);

        // Actually getPropertySlot, not getOwnPropertySlot (see JSCell).
        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier& propertyName, PropertySlot&);
        static bool getOwnPropertySlotByIndex(JSCell*, ExecState*, unsigned propertyName, PropertySlot&);

        static const unsigned s_maxInternalRopeLength = 3;

        // A string is represented either by a UString or a rope of fibers.
        bool m_is8Bit : 1;
        unsigned m_length;
        mutable UString m_value;
        mutable FixedArray<WriteBarrier<JSString>, s_maxInternalRopeLength> m_fibers;

        bool isRope() const { return m_value.isNull(); }
        bool is8Bit() const { return m_is8Bit; }
        UString& string() { ASSERT(!isRope()); return m_value; }

        friend JSValue jsString(ExecState*, JSString*, JSString*);
        friend JSValue jsString(ExecState*, Register*, unsigned count);
        friend JSValue jsStringFromArguments(ExecState*, JSValue thisValue);
        friend JSString* jsSubstring(ExecState*, JSString*, unsigned offset, unsigned length);
    };

    JSString* asString(JSValue);

    inline JSString* asString(JSValue value)
    {
        ASSERT(value.asCell()->isString());
        return static_cast<JSString*>(value.asCell());
    }

    inline JSString* jsEmptyString(JSGlobalData* globalData)
    {
        return globalData->smallStrings.emptyString(globalData);
    }

    inline JSString* jsSingleCharacterString(JSGlobalData* globalData, UChar c)
    {
        if (c <= maxSingleCharacterString)
            return globalData->smallStrings.singleCharacterString(globalData, c);
        return JSString::create(*globalData, UString(&c, 1).impl());
    }

    inline JSString* jsSingleCharacterSubstring(ExecState* exec, const UString& s, unsigned offset)
    {
        JSGlobalData* globalData = &exec->globalData();
        ASSERT(offset < static_cast<unsigned>(s.length()));
        UChar c = s[offset];
        if (c <= maxSingleCharacterString)
            return globalData->smallStrings.singleCharacterString(globalData, c);
        return JSString::create(*globalData, StringImpl::create(s.impl(), offset, 1));
    }

    inline JSString* jsNontrivialString(JSGlobalData* globalData, const char* s)
    {
        ASSERT(s);
        ASSERT(s[0]);
        ASSERT(s[1]);
        return JSString::create(*globalData, UString(s).impl());
    }

    inline JSString* jsNontrivialString(JSGlobalData* globalData, const UString& s)
    {
        ASSERT(s.length() > 1);
        return JSString::create(*globalData, s.impl());
    }

    inline JSString* JSString::getIndex(ExecState* exec, unsigned i)
    {
        ASSERT(canGetIndex(i));
        if (isRope())
            return getIndexSlowCase(exec, i);
        ASSERT(i < m_value.length());
        return jsSingleCharacterSubstring(exec, m_value, i);
    }

    inline JSString* jsString(JSGlobalData* globalData, const UString& s)
    {
        int size = s.length();
        if (!size)
            return globalData->smallStrings.emptyString(globalData);
        if (size == 1) {
            UChar c = s[0];
            if (c <= maxSingleCharacterString)
                return globalData->smallStrings.singleCharacterString(globalData, c);
        }
        return JSString::create(*globalData, s.impl());
    }

    inline JSString* jsSubstring(ExecState* exec, JSString* s, unsigned offset, unsigned length)
    {
        ASSERT(offset <= static_cast<unsigned>(s->length()));
        ASSERT(length <= static_cast<unsigned>(s->length()));
        ASSERT(offset + length <= static_cast<unsigned>(s->length()));
        JSGlobalData* globalData = &exec->globalData();
        if (!length)
            return globalData->smallStrings.emptyString(globalData);
        return jsSubstring(globalData, s->value(exec), offset, length);
    }

    inline JSString* jsSubstring8(JSGlobalData* globalData, const UString& s, unsigned offset, unsigned length)
    {
        ASSERT(offset <= static_cast<unsigned>(s.length()));
        ASSERT(length <= static_cast<unsigned>(s.length()));
        ASSERT(offset + length <= static_cast<unsigned>(s.length()));
        if (!length)
            return globalData->smallStrings.emptyString(globalData);
        if (length == 1) {
            UChar c = s[offset];
            if (c <= maxSingleCharacterString)
                return globalData->smallStrings.singleCharacterString(globalData, c);
        }
        return JSString::createHasOtherOwner(*globalData, StringImpl::create8(s.impl(), offset, length));
    }

    inline JSString* jsSubstring(JSGlobalData* globalData, const UString& s, unsigned offset, unsigned length)
    {
        ASSERT(offset <= static_cast<unsigned>(s.length()));
        ASSERT(length <= static_cast<unsigned>(s.length()));
        ASSERT(offset + length <= static_cast<unsigned>(s.length()));
        if (!length)
            return globalData->smallStrings.emptyString(globalData);
        if (length == 1) {
            UChar c = s[offset];
            if (c <= maxSingleCharacterString)
                return globalData->smallStrings.singleCharacterString(globalData, c);
        }
        return JSString::createHasOtherOwner(*globalData, StringImpl::create(s.impl(), offset, length));
    }

    inline JSString* jsOwnedString(JSGlobalData* globalData, const UString& s)
    {
        int size = s.length();
        if (!size)
            return globalData->smallStrings.emptyString(globalData);
        if (size == 1) {
            UChar c = s[0];
            if (c <= maxSingleCharacterString)
                return globalData->smallStrings.singleCharacterString(globalData, c);
        }
        return JSString::createHasOtherOwner(*globalData, s.impl());
    }

    inline JSString* jsStringBuilder(JSGlobalData* globalData)
    {
        return JSString::createNull(*globalData);
    }

    inline JSString* jsEmptyString(ExecState* exec) { return jsEmptyString(&exec->globalData()); }
    inline JSString* jsString(ExecState* exec, const UString& s) { return jsString(&exec->globalData(), s); }
    inline JSString* jsSingleCharacterString(ExecState* exec, UChar c) { return jsSingleCharacterString(&exec->globalData(), c); }
    inline JSString* jsSubstring8(ExecState* exec, const UString& s, unsigned offset, unsigned length) { return jsSubstring8(&exec->globalData(), s, offset, length); }
    inline JSString* jsSubstring(ExecState* exec, const UString& s, unsigned offset, unsigned length) { return jsSubstring(&exec->globalData(), s, offset, length); }
    inline JSString* jsNontrivialString(ExecState* exec, const UString& s) { return jsNontrivialString(&exec->globalData(), s); }
    inline JSString* jsNontrivialString(ExecState* exec, const char* s) { return jsNontrivialString(&exec->globalData(), s); }
    inline JSString* jsOwnedString(ExecState* exec, const UString& s) { return jsOwnedString(&exec->globalData(), s); } 

    ALWAYS_INLINE bool JSString::getStringPropertySlot(ExecState* exec, const Identifier& propertyName, PropertySlot& slot)
    {
        if (propertyName == exec->propertyNames().length) {
            slot.setValue(jsNumber(m_length));
            return true;
        }

        bool isStrictUInt32;
        unsigned i = propertyName.toUInt32(isStrictUInt32);
        if (isStrictUInt32 && i < m_length) {
            slot.setValue(getIndex(exec, i));
            return true;
        }

        return false;
    }
        
    ALWAYS_INLINE bool JSString::getStringPropertySlot(ExecState* exec, unsigned propertyName, PropertySlot& slot)
    {
        if (propertyName < m_length) {
            slot.setValue(getIndex(exec, propertyName));
            return true;
        }

        return false;
    }

    inline bool isJSString(JSValue v) { return v.isCell() && v.asCell()->classInfo() == &JSString::s_info; }

    inline bool JSCell::toBoolean(ExecState* exec) const
    {
        if (isString()) 
            return static_cast<const JSString*>(this)->toBoolean(exec);
        return !structure()->typeInfo().masqueradesAsUndefined();
    }

    // --- JSValue inlines ----------------------------
    
    inline bool JSValue::toBoolean(ExecState* exec) const
    {
        if (isInt32())
            return asInt32();
        if (isDouble())
            return asDouble() > 0.0 || asDouble() < 0.0; // false for NaN
        if (isCell())
            return asCell()->toBoolean(exec);
        return isTrue(); // false, null, and undefined all convert to false.
    }

    inline JSString* JSValue::toString(ExecState* exec) const
    {
        if (isString())
            return static_cast<JSString*>(asCell());
        return toStringSlowCase(exec);
    }

} // namespace JSC

#endif // JSString_h
