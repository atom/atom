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

#ifndef DataFormat_h
#define DataFormat_h

#include <wtf/Assertions.h>

namespace JSC {

// === DataFormat ===
//
// This enum tracks the current representation in which a value is being held.
// Values may be unboxed primitives (int32, double, or cell), or boxed as a JSValue.
// For boxed values, we may know the type of boxing that has taken place.
// (May also need bool, array, object, string types!)
enum DataFormat {
    DataFormatNone = 0,
    DataFormatInteger = 1,
    DataFormatDouble = 2,
    DataFormatBoolean = 3,
    DataFormatCell = 4,
    DataFormatStorage = 5,
    DataFormatJS = 8,
    DataFormatJSInteger = DataFormatJS | DataFormatInteger,
    DataFormatJSDouble = DataFormatJS | DataFormatDouble,
    DataFormatJSCell = DataFormatJS | DataFormatCell,
    DataFormatJSBoolean = DataFormatJS | DataFormatBoolean
};

#ifndef NDEBUG
inline const char* dataFormatToString(DataFormat dataFormat)
{
    switch (dataFormat) {
    case DataFormatNone:
        return "None";
    case DataFormatInteger:
        return "Integer";
    case DataFormatDouble:
        return "Double";
    case DataFormatCell:
        return "Cell";
    case DataFormatBoolean:
        return "Boolean";
    case DataFormatStorage:
        return "Storage";
    case DataFormatJS:
        return "JS";
    case DataFormatJSInteger:
        return "JSInteger";
    case DataFormatJSDouble:
        return "JSDouble";
    case DataFormatJSCell:
        return "JSCell";
    case DataFormatJSBoolean:
        return "JSBoolean";
    default:
        return "Unknown";
    }
}
#endif

#if USE(JSVALUE64)
inline bool needDataFormatConversion(DataFormat from, DataFormat to)
{
    ASSERT(from != DataFormatNone);
    ASSERT(to != DataFormatNone);
    switch (from) {
    case DataFormatInteger:
    case DataFormatDouble:
        return to != from;
    case DataFormatCell:
    case DataFormatJS:
    case DataFormatJSInteger:
    case DataFormatJSDouble:
    case DataFormatJSCell:
    case DataFormatJSBoolean:
        switch (to) {
        case DataFormatInteger:
        case DataFormatDouble:
            return true;
        case DataFormatCell:
        case DataFormatJS:
        case DataFormatJSInteger:
        case DataFormatJSDouble:
        case DataFormatJSCell:
        case DataFormatJSBoolean:
            return false;
        default:
            // This captures DataFormatBoolean, which is currently unused.
            ASSERT_NOT_REACHED();
        }
    case DataFormatStorage:
        ASSERT(to == DataFormatStorage);
        return false;
    default:
        // This captures DataFormatBoolean, which is currently unused.
        ASSERT_NOT_REACHED();
    }
    return true;
}

#elif USE(JSVALUE32_64)
inline bool needDataFormatConversion(DataFormat from, DataFormat to)
{
    ASSERT(from != DataFormatNone);
    ASSERT(to != DataFormatNone);
    switch (from) {
    case DataFormatInteger:
    case DataFormatCell:
    case DataFormatBoolean:
        return ((to & DataFormatJS) || to == DataFormatDouble);
    case DataFormatDouble:
    case DataFormatJSDouble:
        return (to != DataFormatDouble && to != DataFormatJSDouble);
    case DataFormatJS:
    case DataFormatJSInteger:
    case DataFormatJSCell:
    case DataFormatJSBoolean:
        return (!(to & DataFormatJS) || to == DataFormatJSDouble);
    case DataFormatStorage:
        ASSERT(to == DataFormatStorage);
        return false;
    default:
        ASSERT_NOT_REACHED();
    }
    return true;
}
#endif

inline bool isJSFormat(DataFormat format, DataFormat expectedFormat)
{
    ASSERT(expectedFormat & DataFormatJS);
    return (format | DataFormatJS) == expectedFormat;
}

inline bool isJSInteger(DataFormat format)
{
    return isJSFormat(format, DataFormatJSInteger);
}

inline bool isJSDouble(DataFormat format)
{
    return isJSFormat(format, DataFormatJSDouble);
}

inline bool isJSCell(DataFormat format)
{
    return isJSFormat(format, DataFormatJSCell);
}

inline bool isJSBoolean(DataFormat format)
{
    return isJSFormat(format, DataFormatJSBoolean);
}

}

#endif // DataFormat_h
