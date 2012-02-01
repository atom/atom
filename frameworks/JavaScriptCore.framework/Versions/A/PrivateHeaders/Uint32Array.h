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

#ifndef Uint32Array_h
#define Uint32Array_h

#include "IntegralTypedArrayBase.h"

namespace WTF {

class ArrayBuffer;

class Uint32Array : public IntegralTypedArrayBase<unsigned int> {
public:
    static inline PassRefPtr<Uint32Array> create(unsigned length);
    static inline PassRefPtr<Uint32Array> create(unsigned int* array, unsigned length);
    static inline PassRefPtr<Uint32Array> create(PassRefPtr<ArrayBuffer>, unsigned byteOffset, unsigned length);

    // Can’t use "using" here due to a bug in the RVCT compiler.
    bool set(TypedArrayBase<unsigned int>* array, unsigned offset) { return TypedArrayBase<unsigned int>::set(array, offset); }
    void set(unsigned index, double value) { IntegralTypedArrayBase<unsigned int>::set(index, value); }

    inline PassRefPtr<Uint32Array> subarray(int start) const;
    inline PassRefPtr<Uint32Array> subarray(int start, int end) const;

private:
    inline Uint32Array(PassRefPtr<ArrayBuffer>,
                          unsigned byteOffset,
                          unsigned length);
    // Make constructor visible to superclass.
    friend class TypedArrayBase<unsigned int>;

    // Overridden from ArrayBufferView.
    virtual bool isUnsignedIntArray() const { return true; }
};

PassRefPtr<Uint32Array> Uint32Array::create(unsigned length)
{
    return TypedArrayBase<unsigned int>::create<Uint32Array>(length);
}

PassRefPtr<Uint32Array> Uint32Array::create(unsigned int* array, unsigned length)
{
    return TypedArrayBase<unsigned int>::create<Uint32Array>(array, length);
}

PassRefPtr<Uint32Array> Uint32Array::create(PassRefPtr<ArrayBuffer> buffer, unsigned byteOffset, unsigned length)
{
    return TypedArrayBase<unsigned int>::create<Uint32Array>(buffer, byteOffset, length);
}

Uint32Array::Uint32Array(PassRefPtr<ArrayBuffer> buffer, unsigned byteOffset, unsigned length)
    : IntegralTypedArrayBase<unsigned int>(buffer, byteOffset, length)
{
}

PassRefPtr<Uint32Array> Uint32Array::subarray(int start) const
{
    return subarray(start, length());
}

PassRefPtr<Uint32Array> Uint32Array::subarray(int start, int end) const
{
    return subarrayImpl<Uint32Array>(start, end);
}

} // namespace WTF

using WTF::Uint32Array;

#endif // Uint32Array_h
