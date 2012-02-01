/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2002, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef Operations_h
#define Operations_h

#include "ExceptionHelpers.h"
#include "Interpreter.h"
#include "JSString.h"
#include "JSValueInlineMethods.h"

namespace JSC {

    NEVER_INLINE JSValue jsAddSlowCase(CallFrame*, JSValue, JSValue);
    JSValue jsTypeStringForValue(CallFrame*, JSValue);
    bool jsIsObjectType(JSValue);
    bool jsIsFunctionType(JSValue);

    ALWAYS_INLINE JSValue jsString(ExecState* exec, JSString* s1, JSString* s2)
    {
        JSGlobalData& globalData = exec->globalData();

        unsigned length1 = s1->length();
        if (!length1)
            return s2;
        unsigned length2 = s2->length();
        if (!length2)
            return s1;
        if ((length1 + length2) < length1)
            return throwOutOfMemoryError(exec);

        return JSString::create(globalData, s1, s2);
    }

    ALWAYS_INLINE JSValue jsString(ExecState* exec, const UString& u1, const UString& u2, const UString& u3)
    {
        JSGlobalData* globalData = &exec->globalData();

        unsigned length1 = u1.length();
        unsigned length2 = u2.length();
        unsigned length3 = u3.length();
        if (!length1)
            return jsString(exec, jsString(globalData, u2), jsString(globalData, u3));
        if (!length2)
            return jsString(exec, jsString(globalData, u1), jsString(globalData, u3));
        if (!length3)
            return jsString(exec, jsString(globalData, u1), jsString(globalData, u2));

        if ((length1 + length2) < length1)
            return throwOutOfMemoryError(exec);
        if ((length1 + length2 + length3) < length3)
            return throwOutOfMemoryError(exec);

        return JSString::create(exec->globalData(), jsString(globalData, u1), jsString(globalData, u2), jsString(globalData, u3));
    }

    ALWAYS_INLINE JSValue jsString(ExecState* exec, Register* strings, unsigned count)
    {
        JSGlobalData* globalData = &exec->globalData();
        JSString::RopeBuilder ropeBuilder(*globalData);

        unsigned oldLength = 0;

        for (unsigned i = 0; i < count; ++i) {
            JSValue v = strings[i].jsValue();
            ropeBuilder.append(v.toString(exec));

            if (ropeBuilder.length() < oldLength) // True for overflow
                return throwOutOfMemoryError(exec);
        }

        return ropeBuilder.release();
    }

    ALWAYS_INLINE JSValue jsStringFromArguments(ExecState* exec, JSValue thisValue)
    {
        JSGlobalData* globalData = &exec->globalData();
        JSString::RopeBuilder ropeBuilder(*globalData);
        ropeBuilder.append(thisValue.toString(exec));

        unsigned oldLength = 0;

        for (unsigned i = 0; i < exec->argumentCount(); ++i) {
            JSValue v = exec->argument(i);
            ropeBuilder.append(v.toString(exec));

            if (ropeBuilder.length() < oldLength) // True for overflow
                return throwOutOfMemoryError(exec);
        }

        return ropeBuilder.release();
    }

    // ECMA 11.9.3
    inline bool JSValue::equal(ExecState* exec, JSValue v1, JSValue v2)
    {
        if (v1.isInt32() && v2.isInt32())
            return v1 == v2;

        return equalSlowCase(exec, v1, v2);
    }

    ALWAYS_INLINE bool JSValue::equalSlowCaseInline(ExecState* exec, JSValue v1, JSValue v2)
    {
        do {
            if (v1.isNumber() && v2.isNumber())
                return v1.asNumber() == v2.asNumber();

            bool s1 = v1.isString();
            bool s2 = v2.isString();
            if (s1 && s2)
                return asString(v1)->value(exec) == asString(v2)->value(exec);

            if (v1.isUndefinedOrNull()) {
                if (v2.isUndefinedOrNull())
                    return true;
                if (!v2.isCell())
                    return false;
                return v2.asCell()->structure()->typeInfo().masqueradesAsUndefined();
            }

            if (v2.isUndefinedOrNull()) {
                if (!v1.isCell())
                    return false;
                return v1.asCell()->structure()->typeInfo().masqueradesAsUndefined();
            }

            if (v1.isObject()) {
                if (v2.isObject())
                    return v1 == v2;
                JSValue p1 = v1.toPrimitive(exec);
                if (exec->hadException())
                    return false;
                v1 = p1;
                if (v1.isInt32() && v2.isInt32())
                    return v1 == v2;
                continue;
            }

            if (v2.isObject()) {
                JSValue p2 = v2.toPrimitive(exec);
                if (exec->hadException())
                    return false;
                v2 = p2;
                if (v1.isInt32() && v2.isInt32())
                    return v1 == v2;
                continue;
            }

            if (s1 || s2) {
                double d1 = v1.toNumber(exec);
                double d2 = v2.toNumber(exec);
                return d1 == d2;
            }

            if (v1.isBoolean()) {
                if (v2.isNumber())
                    return static_cast<double>(v1.asBoolean()) == v2.asNumber();
            } else if (v2.isBoolean()) {
                if (v1.isNumber())
                    return v1.asNumber() == static_cast<double>(v2.asBoolean());
            }

            return v1 == v2;
        } while (true);
    }

    // ECMA 11.9.3
    ALWAYS_INLINE bool JSValue::strictEqualSlowCaseInline(ExecState* exec, JSValue v1, JSValue v2)
    {
        ASSERT(v1.isCell() && v2.isCell());

        if (v1.asCell()->isString() && v2.asCell()->isString())
            return asString(v1)->value(exec) == asString(v2)->value(exec);

        return v1 == v2;
    }

    inline bool JSValue::strictEqual(ExecState* exec, JSValue v1, JSValue v2)
    {
        if (v1.isInt32() && v2.isInt32())
            return v1 == v2;

        if (v1.isNumber() && v2.isNumber())
            return v1.asNumber() == v2.asNumber();

        if (!v1.isCell() || !v2.isCell())
            return v1 == v2;

        return strictEqualSlowCaseInline(exec, v1, v2);
    }

    // See ES5 11.8.1/11.8.2/11.8.5 for definition of leftFirst, this value ensures correct
    // evaluation ordering for argument conversions for '<' and '>'. For '<' pass the value
    // true, for leftFirst, for '>' pass the value false (and reverse operand order).
    template<bool leftFirst>
    ALWAYS_INLINE bool jsLess(CallFrame* callFrame, JSValue v1, JSValue v2)
    {
        if (v1.isInt32() && v2.isInt32())
            return v1.asInt32() < v2.asInt32();

        if (v1.isNumber() && v2.isNumber())
            return v1.asNumber() < v2.asNumber();

        if (isJSString(v1) && isJSString(v2))
            return asString(v1)->value(callFrame) < asString(v2)->value(callFrame);

        double n1;
        double n2;
        JSValue p1;
        JSValue p2;
        bool wasNotString1;
        bool wasNotString2;
        if (leftFirst) {
            wasNotString1 = v1.getPrimitiveNumber(callFrame, n1, p1);
            wasNotString2 = v2.getPrimitiveNumber(callFrame, n2, p2);
        } else {
            wasNotString2 = v2.getPrimitiveNumber(callFrame, n2, p2);
            wasNotString1 = v1.getPrimitiveNumber(callFrame, n1, p1);
        }

        if (wasNotString1 | wasNotString2)
            return n1 < n2;
        return asString(p1)->value(callFrame) < asString(p2)->value(callFrame);
    }

    // See ES5 11.8.3/11.8.4/11.8.5 for definition of leftFirst, this value ensures correct
    // evaluation ordering for argument conversions for '<=' and '=>'. For '<=' pass the
    // value true, for leftFirst, for '=>' pass the value false (and reverse operand order).
    template<bool leftFirst>
    ALWAYS_INLINE bool jsLessEq(CallFrame* callFrame, JSValue v1, JSValue v2)
    {
        if (v1.isInt32() && v2.isInt32())
            return v1.asInt32() <= v2.asInt32();

        if (v1.isNumber() && v2.isNumber())
            return v1.asNumber() <= v2.asNumber();

        if (isJSString(v1) && isJSString(v2))
            return !(asString(v2)->value(callFrame) < asString(v1)->value(callFrame));

        double n1;
        double n2;
        JSValue p1;
        JSValue p2;
        bool wasNotString1;
        bool wasNotString2;
        if (leftFirst) {
            wasNotString1 = v1.getPrimitiveNumber(callFrame, n1, p1);
            wasNotString2 = v2.getPrimitiveNumber(callFrame, n2, p2);
        } else {
            wasNotString2 = v2.getPrimitiveNumber(callFrame, n2, p2);
            wasNotString1 = v1.getPrimitiveNumber(callFrame, n1, p1);
        }

        if (wasNotString1 | wasNotString2)
            return n1 <= n2;
        return !(asString(p2)->value(callFrame) < asString(p1)->value(callFrame));
    }

    // Fast-path choices here are based on frequency data from SunSpider:
    //    <times> Add case: <t1> <t2>
    //    ---------------------------
    //    5626160 Add case: 3 3 (of these, 3637690 are for immediate values)
    //    247412  Add case: 5 5
    //    20900   Add case: 5 6
    //    13962   Add case: 5 3
    //    4000    Add case: 3 5

    ALWAYS_INLINE JSValue jsAdd(CallFrame* callFrame, JSValue v1, JSValue v2)
    {
        if (v1.isNumber() && v2.isNumber())
            return jsNumber(v1.asNumber() + v2.asNumber());
        
        if (v1.isString() && !v2.isObject())
            return jsString(callFrame, asString(v1), v2.toString(callFrame));

        // All other cases are pretty uncommon
        return jsAddSlowCase(callFrame, v1, v2);
    }

    inline size_t normalizePrototypeChain(CallFrame* callFrame, JSValue base, JSValue slotBase, const Identifier& propertyName, size_t& slotOffset)
    {
        JSCell* cell = base.asCell();
        size_t count = 0;

        while (slotBase != cell) {
            JSValue v = cell->structure()->prototypeForLookup(callFrame);

            // If we didn't find slotBase in base's prototype chain, then base
            // must be a proxy for another object.

            if (v.isNull())
                return 0;

            cell = v.asCell();

            // Since we're accessing a prototype in a loop, it's a good bet that it
            // should not be treated as a dictionary.
            if (cell->structure()->isDictionary()) {
                asObject(cell)->flattenDictionaryObject(callFrame->globalData());
                if (slotBase == cell)
                    slotOffset = cell->structure()->get(callFrame->globalData(), propertyName); 
            }

            ++count;
        }
        
        ASSERT(count);
        return count;
    }

    inline size_t normalizePrototypeChain(CallFrame* callFrame, JSCell* base)
    {
        size_t count = 0;
        while (1) {
            JSValue v = base->structure()->prototypeForLookup(callFrame);
            if (v.isNull())
                return count;

            base = v.asCell();

            // Since we're accessing a prototype in a loop, it's a good bet that it
            // should not be treated as a dictionary.
            if (base->structure()->isDictionary())
                asObject(base)->flattenDictionaryObject(callFrame->globalData());

            ++count;
        }
    }

    ALWAYS_INLINE JSValue resolveBase(CallFrame* callFrame, Identifier& property, ScopeChainNode* scopeChain, bool isStrictPut)
    {
        ScopeChainIterator iter = scopeChain->begin();
        ScopeChainIterator next = iter;
        ++next;
        ScopeChainIterator end = scopeChain->end();
        ASSERT(iter != end);

        PropertySlot slot;
        JSObject* base;
        while (true) {
            base = iter->get();
            if (next == end) {
                if (isStrictPut && !base->getPropertySlot(callFrame, property, slot))
                    return JSValue();
                return base;
            }
            if (base->getPropertySlot(callFrame, property, slot))
                return base;

            iter = next;
            ++next;
        }

        ASSERT_NOT_REACHED();
        return JSValue();
    }
} // namespace JSC

#endif // Operations_h
