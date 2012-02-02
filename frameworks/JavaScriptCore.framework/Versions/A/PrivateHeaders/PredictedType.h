/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef PredictedType_h
#define PredictedType_h

#include "JSValue.h"

namespace JSC {

class Structure;

typedef uint32_t PredictedType;
static const PredictedType PredictNone              = 0x00000000; // We don't know anything yet.
static const PredictedType PredictFinalObject       = 0x00000001; // It's definitely a JSFinalObject.
static const PredictedType PredictArray             = 0x00000002; // It's definitely a JSArray.
static const PredictedType PredictByteArray         = 0x00000004; // It's definitely a JSByteArray or one of its subclasses.
static const PredictedType PredictFunction          = 0x00000008; // It's definitely a JSFunction or one of its subclasses.
static const PredictedType PredictInt8Array         = 0x00000010; // It's definitely an Int8Array or one of its subclasses.
static const PredictedType PredictInt16Array        = 0x00000020; // It's definitely an Int16Array or one of its subclasses.
static const PredictedType PredictInt32Array        = 0x00000040; // It's definitely an Int32Array or one of its subclasses.
static const PredictedType PredictUint8Array        = 0x00000080; // It's definitely an Uint8Array or one of its subclasses.
static const PredictedType PredictUint8ClampedArray = 0x00000100; // It's definitely an Uint8ClampedArray or one of its subclasses.
static const PredictedType PredictUint16Array       = 0x00000200; // It's definitely an Uint16Array or one of its subclasses.
static const PredictedType PredictUint32Array       = 0x00000400; // It's definitely an Uint32Array or one of its subclasses.
static const PredictedType PredictFloat32Array      = 0x00000800; // It's definitely an Uint16Array or one of its subclasses.
static const PredictedType PredictFloat64Array      = 0x00001000; // It's definitely an Uint16Array or one of its subclasses.
static const PredictedType PredictObjectOther       = 0x00002000; // It's definitely an object but not JSFinalObject, JSArray, JSByteArray, or JSFunction.
static const PredictedType PredictObjectMask        = 0x00003fff; // Bitmask used for testing for any kind of object prediction.
static const PredictedType PredictString            = 0x00004000; // It's definitely a JSString.
static const PredictedType PredictCellOther         = 0x00008000; // It's definitely a JSCell but not a subclass of JSObject and definitely not a JSString.
static const PredictedType PredictCell              = 0x0000ffff; // It's definitely a JSCell.
static const PredictedType PredictInt32             = 0x00010000; // It's definitely an Int32.
static const PredictedType PredictDoubleReal        = 0x00020000; // It's definitely a non-NaN double.
static const PredictedType PredictDoubleNaN         = 0x00040000; // It's definitely a NaN.
static const PredictedType PredictDouble            = 0x00060000; // It's either a non-NaN or a NaN double.
static const PredictedType PredictNumber            = 0x00070000; // It's either an Int32 or a Double.
static const PredictedType PredictBoolean           = 0x00080000; // It's definitely a Boolean.
static const PredictedType PredictOther             = 0x40000000; // It's definitely none of the above.
static const PredictedType PredictTop               = 0x7fffffff; // It can be any of the above.
static const PredictedType FixedIndexedStorageMask = PredictByteArray | PredictInt8Array | PredictInt16Array | PredictInt32Array | PredictUint8Array | PredictUint8ClampedArray | PredictUint16Array | PredictUint32Array | PredictFloat32Array | PredictFloat64Array;

typedef bool (*PredictionChecker)(PredictedType);

inline bool isCellPrediction(PredictedType value)
{
    return !!(value & PredictCell) && !(value & ~PredictCell);
}

inline bool isObjectPrediction(PredictedType value)
{
    return !!(value & PredictObjectMask) && !(value & ~PredictObjectMask);
}

inline bool isFinalObjectPrediction(PredictedType value)
{
    return value == PredictFinalObject;
}

inline bool isFinalObjectOrOtherPrediction(PredictedType value)
{
    return !!(value & (PredictFinalObject | PredictOther)) && !(value & ~(PredictFinalObject | PredictOther));
}

inline bool isFixedIndexedStorageObjectPrediction(PredictedType value)
{
    return (value & FixedIndexedStorageMask) == value;
}

inline bool isStringPrediction(PredictedType value)
{
    return value == PredictString;
}

inline bool isArrayPrediction(PredictedType value)
{
    return value == PredictArray;
}

inline bool isFunctionPrediction(PredictedType value)
{
    return value == PredictFunction;
}

inline bool isByteArrayPrediction(PredictedType value)
{
    return value == PredictByteArray;
}

inline bool isInt8ArrayPrediction(PredictedType value)
{
    return value == PredictInt8Array;
}

inline bool isInt16ArrayPrediction(PredictedType value)
{
    return value == PredictInt16Array;
}

inline bool isInt32ArrayPrediction(PredictedType value)
{
    return value == PredictInt32Array;
}

inline bool isUint8ArrayPrediction(PredictedType value)
{
    return value == PredictUint8Array;
}

inline bool isUint8ClampedArrayPrediction(PredictedType value)
{
    return value == PredictUint8ClampedArray;
}

inline bool isUint16ArrayPrediction(PredictedType value)
{
    return value == PredictUint16Array;
}

inline bool isUint32ArrayPrediction(PredictedType value)
{
    return value == PredictUint32Array;
}

inline bool isFloat32ArrayPrediction(PredictedType value)
{
    return value == PredictFloat32Array;
}

inline bool isFloat64ArrayPrediction(PredictedType value)
{
    return value == PredictFloat64Array;
}

inline bool isActionableMutableArrayPrediction(PredictedType value)
{
    return isArrayPrediction(value)
        || isByteArrayPrediction(value)
#if CPU(X86) || CPU(X86_64)
        || isInt8ArrayPrediction(value)
        || isInt16ArrayPrediction(value)
#endif
        || isInt32ArrayPrediction(value)
        || isUint8ArrayPrediction(value)
        || isUint8ClampedArrayPrediction(value)
        || isUint16ArrayPrediction(value)
        || isUint32ArrayPrediction(value)
#if CPU(X86) || CPU(X86_64)
        || isFloat32ArrayPrediction(value)
#endif
        || isFloat64ArrayPrediction(value);
}

inline bool isActionableArrayPrediction(PredictedType value)
{
    return isStringPrediction(value)
        || isActionableMutableArrayPrediction(value);
}

inline bool isArrayOrOtherPrediction(PredictedType value)
{
    return !!(value & (PredictArray | PredictOther)) && !(value & ~(PredictArray | PredictOther));
}

inline bool isInt32Prediction(PredictedType value)
{
    return value == PredictInt32;
}

inline bool isDoubleRealPrediction(PredictedType value)
{
    return value == PredictDoubleReal;
}

inline bool isDoublePrediction(PredictedType value)
{
    return (value & PredictDouble) == value;
}

inline bool isNumberPrediction(PredictedType value)
{
    return !!(value & PredictNumber) && !(value & ~PredictNumber);
}

inline bool isBooleanPrediction(PredictedType value)
{
    return value == PredictBoolean;
}

inline bool isOtherPrediction(PredictedType value)
{
    return value == PredictOther;
}

#ifndef NDEBUG
const char* predictionToString(PredictedType value);
#endif

// Merge two predictions. Note that currently this just does left | right. It may
// seem tempting to do so directly, but you would be doing so at your own peril,
// since the merging protocol PredictedType may change at any time (and has already
// changed several times in its history).
inline PredictedType mergePredictions(PredictedType left, PredictedType right)
{
    return left | right;
}

template<typename T>
inline bool mergePrediction(T& left, PredictedType right)
{
    PredictedType newPrediction = static_cast<T>(mergePredictions(static_cast<PredictedType>(left), right));
    bool result = newPrediction != static_cast<PredictedType>(left);
    left = newPrediction;
    return result;
}

PredictedType predictionFromClassInfo(const ClassInfo*);
PredictedType predictionFromStructure(Structure*);
PredictedType predictionFromCell(JSCell*);
PredictedType predictionFromValue(JSValue);

} // namespace JSC

#endif // PredictedType_h
