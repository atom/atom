/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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

#ifndef JSValueInlineMethods_h
#define JSValueInlineMethods_h

#include "JSValue.h"

namespace JSC {

    ALWAYS_INLINE int32_t JSValue::toInt32(ExecState* exec) const
    {
        if (isInt32())
            return asInt32();
        return JSC::toInt32(toNumber(exec));
    }

    inline uint32_t JSValue::toUInt32(ExecState* exec) const
    {
        // See comment on JSC::toUInt32, above.
        return toInt32(exec);
    }

    inline bool JSValue::isUInt32() const
    {
        return isInt32() && asInt32() >= 0;
    }

    inline uint32_t JSValue::asUInt32() const
    {
        ASSERT(isUInt32());
        return asInt32();
    }

    inline double JSValue::asNumber() const
    {
        ASSERT(isNumber());
        return isInt32() ? asInt32() : asDouble();
    }

    inline JSValue jsNaN()
    {
        return JSValue(std::numeric_limits<double>::quiet_NaN());
    }

    inline JSValue::JSValue(char i)
    {
        *this = JSValue(static_cast<int32_t>(i));
    }

    inline JSValue::JSValue(unsigned char i)
    {
        *this = JSValue(static_cast<int32_t>(i));
    }

    inline JSValue::JSValue(short i)
    {
        *this = JSValue(static_cast<int32_t>(i));
    }

    inline JSValue::JSValue(unsigned short i)
    {
        *this = JSValue(static_cast<int32_t>(i));
    }

    inline JSValue::JSValue(unsigned i)
    {
        if (static_cast<int32_t>(i) < 0) {
            *this = JSValue(EncodeAsDouble, static_cast<double>(i));
            return;
        }
        *this = JSValue(static_cast<int32_t>(i));
    }

    inline JSValue::JSValue(long i)
    {
        if (static_cast<int32_t>(i) != i) {
            *this = JSValue(EncodeAsDouble, static_cast<double>(i));
            return;
        }
        *this = JSValue(static_cast<int32_t>(i));
    }

    inline JSValue::JSValue(unsigned long i)
    {
        if (static_cast<uint32_t>(i) != i) {
            *this = JSValue(EncodeAsDouble, static_cast<double>(i));
            return;
        }
        *this = JSValue(static_cast<uint32_t>(i));
    }

    inline JSValue::JSValue(long long i)
    {
        if (static_cast<int32_t>(i) != i) {
            *this = JSValue(EncodeAsDouble, static_cast<double>(i));
            return;
        }
        *this = JSValue(static_cast<int32_t>(i));
    }

    inline JSValue::JSValue(unsigned long long i)
    {
        if (static_cast<uint32_t>(i) != i) {
            *this = JSValue(EncodeAsDouble, static_cast<double>(i));
            return;
        }
        *this = JSValue(static_cast<uint32_t>(i));
    }

    inline JSValue::JSValue(double d)
    {
        const int32_t asInt32 = static_cast<int32_t>(d);
        if (asInt32 != d || (!asInt32 && signbit(d))) { // true for -0.0
            *this = JSValue(EncodeAsDouble, d);
            return;
        }
        *this = JSValue(static_cast<int32_t>(d));
    }

#if USE(JSVALUE32_64)
    inline EncodedJSValue JSValue::encode(JSValue value)
    {
        return value.u.asInt64;
    }

    inline JSValue JSValue::decode(EncodedJSValue encodedJSValue)
    {
        JSValue v;
        v.u.asInt64 = encodedJSValue;
        return v;
    }

    inline JSValue::JSValue()
    {
        u.asBits.tag = EmptyValueTag;
        u.asBits.payload = 0;
    }

    inline JSValue::JSValue(JSNullTag)
    {
        u.asBits.tag = NullTag;
        u.asBits.payload = 0;
    }
    
    inline JSValue::JSValue(JSUndefinedTag)
    {
        u.asBits.tag = UndefinedTag;
        u.asBits.payload = 0;
    }
    
    inline JSValue::JSValue(JSTrueTag)
    {
        u.asBits.tag = BooleanTag;
        u.asBits.payload = 1;
    }
    
    inline JSValue::JSValue(JSFalseTag)
    {
        u.asBits.tag = BooleanTag;
        u.asBits.payload = 0;
    }

    inline JSValue::JSValue(HashTableDeletedValueTag)
    {
        u.asBits.tag = DeletedValueTag;
        u.asBits.payload = 0;
    }

    inline JSValue::JSValue(JSCell* ptr)
    {
        if (ptr)
            u.asBits.tag = CellTag;
        else
            u.asBits.tag = EmptyValueTag;
        u.asBits.payload = reinterpret_cast<int32_t>(ptr);
    }

    inline JSValue::JSValue(const JSCell* ptr)
    {
        if (ptr)
            u.asBits.tag = CellTag;
        else
            u.asBits.tag = EmptyValueTag;
        u.asBits.payload = reinterpret_cast<int32_t>(const_cast<JSCell*>(ptr));
    }

    inline JSValue::operator bool() const
    {
        ASSERT(tag() != DeletedValueTag);
        return tag() != EmptyValueTag;
    }

    inline bool JSValue::operator==(const JSValue& other) const
    {
        return u.asInt64 == other.u.asInt64;
    }

    inline bool JSValue::operator!=(const JSValue& other) const
    {
        return u.asInt64 != other.u.asInt64;
    }

    inline bool JSValue::isEmpty() const
    {
        return tag() == EmptyValueTag;
    }

    inline bool JSValue::isUndefined() const
    {
        return tag() == UndefinedTag;
    }

    inline bool JSValue::isNull() const
    {
        return tag() == NullTag;
    }

    inline bool JSValue::isUndefinedOrNull() const
    {
        return isUndefined() || isNull();
    }

    inline bool JSValue::isCell() const
    {
        return tag() == CellTag;
    }

    inline bool JSValue::isInt32() const
    {
        return tag() == Int32Tag;
    }

    inline bool JSValue::isDouble() const
    {
        return tag() < LowestTag;
    }

    inline bool JSValue::isTrue() const
    {
        return tag() == BooleanTag && payload();
    }

    inline bool JSValue::isFalse() const
    {
        return tag() == BooleanTag && !payload();
    }

    inline uint32_t JSValue::tag() const
    {
        return u.asBits.tag;
    }
    
    inline int32_t JSValue::payload() const
    {
        return u.asBits.payload;
    }
    
    inline int32_t JSValue::asInt32() const
    {
        ASSERT(isInt32());
        return u.asBits.payload;
    }
    
    inline double JSValue::asDouble() const
    {
        ASSERT(isDouble());
        return u.asDouble;
    }
    
    ALWAYS_INLINE JSCell* JSValue::asCell() const
    {
        ASSERT(isCell());
        return reinterpret_cast<JSCell*>(u.asBits.payload);
    }

    ALWAYS_INLINE JSValue::JSValue(EncodeAsDoubleTag, double d)
    {
        u.asDouble = d;
    }

    inline JSValue::JSValue(int i)
    {
        u.asBits.tag = Int32Tag;
        u.asBits.payload = i;
    }

    inline bool JSValue::isNumber() const
    {
        return isInt32() || isDouble();
    }

    inline bool JSValue::isBoolean() const
    {
        return isTrue() || isFalse();
    }

    inline bool JSValue::asBoolean() const
    {
        ASSERT(isBoolean());
        return payload();
    }

#else // USE(JSVALUE32_64)

    // JSValue member functions.
    inline EncodedJSValue JSValue::encode(JSValue value)
    {
        return value.u.ptr;
    }

    inline JSValue JSValue::decode(EncodedJSValue ptr)
    {
        return JSValue(reinterpret_cast<JSCell*>(ptr));
    }

    // 0x0 can never occur naturally because it has a tag of 00, indicating a pointer value, but a payload of 0x0, which is in the (invalid) zero page.
    inline JSValue::JSValue()
    {
        u.asInt64 = ValueEmpty;
    }

    // 0x4 can never occur naturally because it has a tag of 00, indicating a pointer value, but a payload of 0x4, which is in the (invalid) zero page.
    inline JSValue::JSValue(HashTableDeletedValueTag)
    {
        u.asInt64 = ValueDeleted;
    }

    inline JSValue::JSValue(JSCell* ptr)
    {
        u.ptr = ptr;
    }

    inline JSValue::JSValue(const JSCell* ptr)
    {
        u.ptr = const_cast<JSCell*>(ptr);
    }

    inline JSValue::operator bool() const
    {
        return u.ptr;
    }

    inline bool JSValue::operator==(const JSValue& other) const
    {
        return u.ptr == other.u.ptr;
    }

    inline bool JSValue::operator!=(const JSValue& other) const
    {
        return u.ptr != other.u.ptr;
    }

    inline bool JSValue::isEmpty() const
    {
        return u.asInt64 == ValueEmpty;
    }

    inline bool JSValue::isUndefined() const
    {
        return asValue() == JSValue(JSUndefined);
    }

    inline bool JSValue::isNull() const
    {
        return asValue() == JSValue(JSNull);
    }

    inline bool JSValue::isTrue() const
    {
        return asValue() == JSValue(JSTrue);
    }

    inline bool JSValue::isFalse() const
    {
        return asValue() == JSValue(JSFalse);
    }

    inline bool JSValue::asBoolean() const
    {
        ASSERT(isBoolean());
        return asValue() == JSValue(JSTrue);
    }

    inline int32_t JSValue::asInt32() const
    {
        ASSERT(isInt32());
        return static_cast<int32_t>(u.asInt64);
    }

    inline bool JSValue::isDouble() const
    {
        return isNumber() && !isInt32();
    }

    inline JSValue::JSValue(JSNullTag)
    {
        u.asInt64 = ValueNull;
    }
    
    inline JSValue::JSValue(JSUndefinedTag)
    {
        u.asInt64 = ValueUndefined;
    }

    inline JSValue::JSValue(JSTrueTag)
    {
        u.asInt64 = ValueTrue;
    }

    inline JSValue::JSValue(JSFalseTag)
    {
        u.asInt64 = ValueFalse;
    }

    inline bool JSValue::isUndefinedOrNull() const
    {
        // Undefined and null share the same value, bar the 'undefined' bit in the extended tag.
        return (u.asInt64 & ~TagBitUndefined) == ValueNull;
    }

    inline bool JSValue::isBoolean() const
    {
        return (u.asInt64 & ~1) == ValueFalse;
    }

    inline bool JSValue::isCell() const
    {
        return !(u.asInt64 & TagMask);
    }

    inline bool JSValue::isInt32() const
    {
        return (u.asInt64 & TagTypeNumber) == TagTypeNumber;
    }

    inline intptr_t reinterpretDoubleToIntptr(double value)
    {
        return bitwise_cast<intptr_t>(value);
    }
    inline double reinterpretIntptrToDouble(intptr_t value)
    {
        return bitwise_cast<double>(value);
    }

    ALWAYS_INLINE JSValue::JSValue(EncodeAsDoubleTag, double d)
    {
        u.asInt64 = reinterpretDoubleToIntptr(d) + DoubleEncodeOffset;
    }

    inline JSValue::JSValue(int i)
    {
        u.asInt64 = TagTypeNumber | static_cast<uint32_t>(i);
    }

    inline double JSValue::asDouble() const
    {
        return reinterpretIntptrToDouble(u.asInt64 - DoubleEncodeOffset);
    }

    inline bool JSValue::isNumber() const
    {
        return u.asInt64 & TagTypeNumber;
    }

    ALWAYS_INLINE JSCell* JSValue::asCell() const
    {
        ASSERT(isCell());
        return u.ptr;
    }

#endif // USE(JSVALUE64)

} // namespace JSC

#endif // JSValueInlineMethods_h
