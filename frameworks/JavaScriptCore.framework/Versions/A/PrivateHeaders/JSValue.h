/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef JSValue_h
#define JSValue_h

#include <math.h>
#include <stddef.h> // for size_t
#include <stdint.h>
#include <wtf/AlwaysInline.h>
#include <wtf/Assertions.h>
#include <wtf/HashMap.h>
#include <wtf/HashTraits.h>
#include <wtf/MathExtras.h>
#include <wtf/StdLibExtras.h>

namespace JSC {

    class ExecState;
    class Identifier;
    class JSCell;
    class JSGlobalData;
    class JSGlobalObject;
    class JSObject;
    class JSString;
    class PropertySlot;
    class PutPropertySlot;
    class UString;
#if ENABLE(DFG_JIT)
    namespace DFG {
        class AssemblyHelpers;
        class JITCompiler;
        class JITCodeGenerator;
        class JSValueSource;
        class OSRExitCompiler;
        class SpeculativeJIT;
    }
#endif

    struct ClassInfo;
    struct Instruction;
    struct MethodTable;

    template <class T> class WriteBarrierBase;

    enum PreferredPrimitiveType { NoPreference, PreferNumber, PreferString };


#if USE(JSVALUE32_64)
    typedef int64_t EncodedJSValue;
#else
    typedef void* EncodedJSValue;
#endif
    
    union EncodedValueDescriptor {
        int64_t asInt64;
#if USE(JSVALUE32_64)
        double asDouble;
#elif USE(JSVALUE64)
        JSCell* ptr;
#endif
        
#if CPU(BIG_ENDIAN)
        struct {
            int32_t tag;
            int32_t payload;
        } asBits;
#else
        struct {
            int32_t payload;
            int32_t tag;
        } asBits;
#endif
    };

    // This implements ToInt32, defined in ECMA-262 9.5.
    JS_EXPORT_PRIVATE int32_t toInt32(double);

    // This implements ToUInt32, defined in ECMA-262 9.6.
    inline uint32_t toUInt32(double number)
    {
        // As commented in the spec, the operation of ToInt32 and ToUint32 only differ
        // in how the result is interpreted; see NOTEs in sections 9.5 and 9.6.
        return toInt32(number);
    }

    class JSValue {
        friend struct EncodedJSValueHashTraits;
        friend class JIT;
        friend class JITStubs;
        friend class JITStubCall;
        friend class JSInterfaceJIT;
        friend class SpecializedThunkJIT;
#if ENABLE(DFG_JIT)
        friend class DFG::AssemblyHelpers;
        friend class DFG::JITCompiler;
        friend class DFG::JITCodeGenerator;
        friend class DFG::JSValueSource;
        friend class DFG::OSRExitCompiler;
        friend class DFG::SpeculativeJIT;
#endif

    public:
        static EncodedJSValue encode(JSValue);
        static JSValue decode(EncodedJSValue);

        enum JSNullTag { JSNull };
        enum JSUndefinedTag { JSUndefined };
        enum JSTrueTag { JSTrue };
        enum JSFalseTag { JSFalse };
        enum EncodeAsDoubleTag { EncodeAsDouble };

        JSValue();
        JSValue(JSNullTag);
        JSValue(JSUndefinedTag);
        JSValue(JSTrueTag);
        JSValue(JSFalseTag);
        JSValue(JSCell* ptr);
        JSValue(const JSCell* ptr);

        // Numbers
        JSValue(EncodeAsDoubleTag, double);
        explicit JSValue(double);
        explicit JSValue(char);
        explicit JSValue(unsigned char);
        explicit JSValue(short);
        explicit JSValue(unsigned short);
        explicit JSValue(int);
        explicit JSValue(unsigned);
        explicit JSValue(long);
        explicit JSValue(unsigned long);
        explicit JSValue(long long);
        explicit JSValue(unsigned long long);

        operator bool() const;
        bool operator==(const JSValue& other) const;
        bool operator!=(const JSValue& other) const;

        bool isInt32() const;
        bool isUInt32() const;
        bool isDouble() const;
        bool isTrue() const;
        bool isFalse() const;

        int32_t asInt32() const;
        uint32_t asUInt32() const;
        double asDouble() const;
        bool asBoolean() const;
        double asNumber() const;

        // Querying the type.
        bool isEmpty() const;
        bool isUndefined() const;
        bool isNull() const;
        bool isUndefinedOrNull() const;
        bool isBoolean() const;
        bool isNumber() const;
        bool isString() const;
        bool isPrimitive() const;
        bool isGetterSetter() const;
        bool isObject() const;
        bool inherits(const ClassInfo*) const;
        
        // Extracting the value.
        bool getString(ExecState* exec, UString&) const;
        UString getString(ExecState* exec) const; // null string if not a string
        JSObject* getObject() const; // 0 if not an object

        // Extracting integer values.
        bool getUInt32(uint32_t&) const;
        
        // Basic conversions.
        JSValue toPrimitive(ExecState*, PreferredPrimitiveType = NoPreference) const;
        bool getPrimitiveNumber(ExecState*, double& number, JSValue&);

        bool toBoolean(ExecState*) const;

        // toNumber conversion is expected to be side effect free if an exception has
        // been set in the ExecState already.
        double toNumber(ExecState*) const;
        JSString* toString(ExecState*) const;
        JSObject* toObject(ExecState*) const;
        JSObject* toObject(ExecState*, JSGlobalObject*) const;

        // Integer conversions.
        JS_EXPORT_PRIVATE double toInteger(ExecState*) const;
        double toIntegerPreserveNaN(ExecState*) const;
        int32_t toInt32(ExecState*) const;
        uint32_t toUInt32(ExecState*) const;

        // Floating point conversions (this is a convenience method for webcore;
        // signle precision float is not a representation used in JS or JSC).
        float toFloat(ExecState* exec) const { return static_cast<float>(toNumber(exec)); }

        // Object operations, with the toObject operation included.
        JSValue get(ExecState*, const Identifier& propertyName) const;
        JSValue get(ExecState*, const Identifier& propertyName, PropertySlot&) const;
        JSValue get(ExecState*, unsigned propertyName) const;
        JSValue get(ExecState*, unsigned propertyName, PropertySlot&) const;
        void put(ExecState*, const Identifier& propertyName, JSValue, PutPropertySlot&);
        void put(ExecState*, unsigned propertyName, JSValue);

        JSObject* toThisObject(ExecState*) const;

        static bool equal(ExecState* exec, JSValue v1, JSValue v2);
        static bool equalSlowCase(ExecState* exec, JSValue v1, JSValue v2);
        static bool equalSlowCaseInline(ExecState* exec, JSValue v1, JSValue v2);
        static bool strictEqual(ExecState* exec, JSValue v1, JSValue v2);
        static bool strictEqualSlowCase(ExecState* exec, JSValue v1, JSValue v2);
        static bool strictEqualSlowCaseInline(ExecState* exec, JSValue v1, JSValue v2);

        bool isCell() const;
        JSCell* asCell() const;
        JS_EXPORT_PRIVATE bool isValidCallee();

#ifndef NDEBUG
        char* description();
#endif

    private:
        template <class T> JSValue(WriteBarrierBase<T>);

        enum HashTableDeletedValueTag { HashTableDeletedValue };
        JSValue(HashTableDeletedValueTag);

        inline const JSValue asValue() const { return *this; }
        JS_EXPORT_PRIVATE double toNumberSlowCase(ExecState*) const;
        JSString* toStringSlowCase(ExecState*) const;
        JS_EXPORT_PRIVATE JSObject* toObjectSlowCase(ExecState*, JSGlobalObject*) const;
        JS_EXPORT_PRIVATE JSObject* toThisObjectSlowCase(ExecState*) const;

        JS_EXPORT_PRIVATE JSObject* synthesizePrototype(ExecState*) const;
        JSObject* synthesizeObject(ExecState*) const;

#if USE(JSVALUE32_64)
        /*
         * On 32-bit platforms USE(JSVALUE32_64) should be defined, and we use a NaN-encoded
         * form for immediates.
         *
         * The encoding makes use of unused NaN space in the IEEE754 representation.  Any value
         * with the top 13 bits set represents a QNaN (with the sign bit set).  QNaN values
         * can encode a 51-bit payload.  Hardware produced and C-library payloads typically
         * have a payload of zero.  We assume that non-zero payloads are available to encode
         * pointer and integer values.  Since any 64-bit bit pattern where the top 15 bits are
         * all set represents a NaN with a non-zero payload, we can use this space in the NaN
         * ranges to encode other values (however there are also other ranges of NaN space that
         * could have been selected).
         *
         * For JSValues that do not contain a double value, the high 32 bits contain the tag
         * values listed in the enums below, which all correspond to NaN-space. In the case of
         * cell, integer and bool values the lower 32 bits (the 'payload') contain the pointer
         * integer or boolean value; in the case of all other tags the payload is 0.
         */
        enum { Int32Tag =        0xffffffff };
        enum { BooleanTag =      0xfffffffe };
        enum { NullTag =         0xfffffffd };
        enum { UndefinedTag =    0xfffffffc };
        enum { CellTag =         0xfffffffb };
        enum { EmptyValueTag =   0xfffffffa };
        enum { DeletedValueTag = 0xfffffff9 };

        enum { LowestTag =  DeletedValueTag };

        uint32_t tag() const;
        int32_t payload() const;
#elif USE(JSVALUE64)
        /*
         * On 64-bit platforms USE(JSVALUE64) should be defined, and we use a NaN-encoded
         * form for immediates.
         *
         * The encoding makes use of unused NaN space in the IEEE754 representation.  Any value
         * with the top 13 bits set represents a QNaN (with the sign bit set).  QNaN values
         * can encode a 51-bit payload.  Hardware produced and C-library payloads typically
         * have a payload of zero.  We assume that non-zero payloads are available to encode
         * pointer and integer values.  Since any 64-bit bit pattern where the top 15 bits are
         * all set represents a NaN with a non-zero payload, we can use this space in the NaN
         * ranges to encode other values (however there are also other ranges of NaN space that
         * could have been selected).
         *
         * This range of NaN space is represented by 64-bit numbers begining with the 16-bit
         * hex patterns 0xFFFE and 0xFFFF - we rely on the fact that no valid double-precision
         * numbers will begin fall in these ranges.
         *
         * The top 16-bits denote the type of the encoded JSValue:
         *
         *     Pointer {  0000:PPPP:PPPP:PPPP
         *              / 0001:****:****:****
         *     Double  {         ...
         *              \ FFFE:****:****:****
         *     Integer {  FFFF:0000:IIII:IIII
         *
         * The scheme we have implemented encodes double precision values by performing a
         * 64-bit integer addition of the value 2^48 to the number. After this manipulation
         * no encoded double-precision value will begin with the pattern 0x0000 or 0xFFFF.
         * Values must be decoded by reversing this operation before subsequent floating point
         * operations my be peformed.
         *
         * 32-bit signed integers are marked with the 16-bit tag 0xFFFF.
         *
         * The tag 0x0000 denotes a pointer, or another form of tagged immediate. Boolean,
         * null and undefined values are represented by specific, invalid pointer values:
         *
         *     False:     0x06
         *     True:      0x07
         *     Undefined: 0x0a
         *     Null:      0x02
         *
         * These values have the following properties:
         * - Bit 1 (TagBitTypeOther) is set for all four values, allowing real pointers to be
         *   quickly distinguished from all immediate values, including these invalid pointers.
         * - With bit 3 is masked out (TagBitUndefined) Undefined and Null share the
         *   same value, allowing null & undefined to be quickly detected.
         *
         * No valid JSValue will have the bit pattern 0x0, this is used to represent array
         * holes, and as a C++ 'no value' result (e.g. JSValue() has an internal value of 0).
         */

        // These values are #defines since using static const integers here is a ~1% regression!

        // This value is 2^48, used to encode doubles such that the encoded value will begin
        // with a 16-bit pattern within the range 0x0001..0xFFFE.
        #define DoubleEncodeOffset 0x1000000000000ll
        // If all bits in the mask are set, this indicates an integer number,
        // if any but not all are set this value is a double precision number.
        #define TagTypeNumber 0xffff000000000000ll

        // All non-numeric (bool, null, undefined) immediates have bit 2 set.
        #define TagBitTypeOther 0x2ll
        #define TagBitBool      0x4ll
        #define TagBitUndefined 0x8ll
        // Combined integer value for non-numeric immediates.
        #define ValueFalse     (TagBitTypeOther | TagBitBool | false)
        #define ValueTrue      (TagBitTypeOther | TagBitBool | true)
        #define ValueUndefined (TagBitTypeOther | TagBitUndefined)
        #define ValueNull      (TagBitTypeOther)

        // TagMask is used to check for all types of immediate values (either number or 'other').
        #define TagMask (TagTypeNumber | TagBitTypeOther)

        // These special values are never visible to JavaScript code; Empty is used to represent
        // Array holes, and for uninitialized JSValues. Deleted is used in hash table code.
        // These values would map to cell types in the JSValue encoding, but not valid GC cell
        // pointer should have either of these values (Empty is null, deleted is at an invalid
        // alignment for a GC cell, and in the zero page).
        #define ValueEmpty   0x0ll
        #define ValueDeleted 0x4ll
#endif

        EncodedValueDescriptor u;
    };

#if USE(JSVALUE32_64)
    typedef IntHash<EncodedJSValue> EncodedJSValueHash;

    struct EncodedJSValueHashTraits : HashTraits<EncodedJSValue> {
        static const bool emptyValueIsZero = false;
        static EncodedJSValue emptyValue() { return JSValue::encode(JSValue()); }
        static void constructDeletedValue(EncodedJSValue& slot) { slot = JSValue::encode(JSValue(JSValue::HashTableDeletedValue)); }
        static bool isDeletedValue(EncodedJSValue value) { return value == JSValue::encode(JSValue(JSValue::HashTableDeletedValue)); }
    };
#else
    typedef PtrHash<EncodedJSValue> EncodedJSValueHash;

    struct EncodedJSValueHashTraits : HashTraits<EncodedJSValue> {
        static void constructDeletedValue(EncodedJSValue& slot) { slot = JSValue::encode(JSValue(JSValue::HashTableDeletedValue)); }
        static bool isDeletedValue(EncodedJSValue value) { return value == JSValue::encode(JSValue(JSValue::HashTableDeletedValue)); }
    };
#endif

    typedef HashMap<EncodedJSValue, unsigned, EncodedJSValueHash, EncodedJSValueHashTraits> JSValueMap;

    // Stand-alone helper functions.
    inline JSValue jsNull()
    {
        return JSValue(JSValue::JSNull);
    }

    inline JSValue jsUndefined()
    {
        return JSValue(JSValue::JSUndefined);
    }

    inline JSValue jsBoolean(bool b)
    {
        return b ? JSValue(JSValue::JSTrue) : JSValue(JSValue::JSFalse);
    }

    ALWAYS_INLINE JSValue jsDoubleNumber(double d)
    {
        ASSERT(JSValue(JSValue::EncodeAsDouble, d).isNumber());
        return JSValue(JSValue::EncodeAsDouble, d);
    }

    ALWAYS_INLINE JSValue jsNumber(double d)
    {
        ASSERT(JSValue(d).isNumber());
        return JSValue(d);
    }

    ALWAYS_INLINE JSValue jsNumber(char i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(unsigned char i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(short i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(unsigned short i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(int i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(unsigned i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(long i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(unsigned long i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(long long i)
    {
        return JSValue(i);
    }

    ALWAYS_INLINE JSValue jsNumber(unsigned long long i)
    {
        return JSValue(i);
    }

    inline bool operator==(const JSValue a, const JSCell* b) { return a == JSValue(b); }
    inline bool operator==(const JSCell* a, const JSValue b) { return JSValue(a) == b; }

    inline bool operator!=(const JSValue a, const JSCell* b) { return a != JSValue(b); }
    inline bool operator!=(const JSCell* a, const JSValue b) { return JSValue(a) != b; }

} // namespace JSC

#endif // JSValue_h
