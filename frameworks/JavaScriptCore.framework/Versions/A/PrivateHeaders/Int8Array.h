/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2009 Google Inc. All rights reserved.
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

#ifndef Int8Array_h
#define Int8Array_h

#include "IntegralTypedArrayBase.h"

namespace WTF {

class ArrayBuffer;

class Int8Array : public IntegralTypedArrayBase<signed char> {
public:
    static inline PassRefPtr<Int8Array> create(unsigned length);
    static inline PassRefPtr<Int8Array> create(signed char* array, unsigned length);
    static inline PassRefPtr<Int8Array> create(PassRefPtr<ArrayBuffer>, unsigned byteOffset, unsigned length);

    // Can’t use "using" here due to a bug in the RVCT compiler.
    bool set(TypedArrayBase<signed char>* array, unsigned offset) { return TypedArrayBase<signed char>::set(array, offset); }
    void set(unsigned index, double value) { IntegralTypedArrayBase<signed char>::set(index, value); }

    inline PassRefPtr<Int8Array> subarray(int start) const;
    inline PassRefPtr<Int8Array> subarray(int start, int end) const;

private:
    inline Int8Array(PassRefPtr<ArrayBuffer>,
                   unsigned byteOffset,
                   unsigned length);
    // Make constructor visible to superclass.
    friend class TypedArrayBase<signed char>;

    // Overridden from ArrayBufferView.
    virtual bool isByteArray() const { return true; }
};

PassRefPtr<Int8Array> Int8Array::create(unsigned length)
{
    return TypedArrayBase<signed char>::create<Int8Array>(length);
}

PassRefPtr<Int8Array> Int8Array::create(signed char* array, unsigned length)
{
    return TypedArrayBase<signed char>::create<Int8Array>(array, length);
}

PassRefPtr<Int8Array> Int8Array::create(PassRefPtr<ArrayBuffer> buffer, unsigned byteOffset, unsigned length)
{
    return TypedArrayBase<signed char>::create<Int8Array>(buffer, byteOffset, length);
}

Int8Array::Int8Array(PassRefPtr<ArrayBuffer> buffer, unsigned byteOffset, unsigned length)
    : IntegralTypedArrayBase<signed char>(buffer, byteOffset, length)
{
}

PassRefPtr<Int8Array> Int8Array::subarray(int start) const
{
    return subarray(start, length());
}

PassRefPtr<Int8Array> Int8Array::subarray(int start, int end) const
{
    return subarrayImpl<Int8Array>(start, end);
}

} // namespace WTF

using WTF::Int8Array;

#endif // Int8Array_h
