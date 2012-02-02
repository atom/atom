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

#ifndef ByteArray_h
#define ByteArray_h

#include <limits.h>
#include <wtf/PassRefPtr.h>
#include <wtf/Platform.h>
#include <wtf/RefCounted.h>
#include <wtf/StdLibExtras.h>

namespace WTF {
    class ByteArray : public RefCountedBase {
    public:
        unsigned length() const { return m_size; }

        void set(unsigned index, double value)
        {
            if (index >= m_size)
                return;
            if (!(value > 0)) // Clamp NaN to 0
                value = 0;
            else if (value > 255)
                value = 255;
            m_data[index] = static_cast<unsigned char>(value + 0.5);
        }

        void set(unsigned index, unsigned char value)
        {
            if (index >= m_size)
                return;
            m_data[index] = value;
        }

        bool get(unsigned index, unsigned char& result) const
        {
            if (index >= m_size)
                return false;
            result = m_data[index];
            return true;
        }

        unsigned char get(unsigned index) const
        {
            ASSERT(index < m_size);
            return m_data[index];
        }

        unsigned char* data() { return m_data; }

        void clear() { memset(m_data, 0, m_size); }

        void deref()
        {
            if (derefBase()) {
                // We allocated with new unsigned char[] in create(),
                // and then used placement new to construct the object.
                this->~ByteArray();
                delete[] reinterpret_cast<unsigned char*>(this);
            }
        }

        WTF_EXPORT_PRIVATE static PassRefPtr<ByteArray> create(size_t size);

        static size_t offsetOfSize() { return OBJECT_OFFSETOF(ByteArray, m_size); }
        static size_t offsetOfData() { return OBJECT_OFFSETOF(ByteArray, m_data); }

    private:
        ByteArray(size_t size)
            : m_size(size)
        {
        }
        size_t m_size;
// MSVC can't handle correctly unsized array.
// warning C4200: nonstandard extension used : zero-sized array in struct/union
// Cannot generate copy-ctor or copy-assignment operator when UDT contains a zero-sized array
#if (COMPILER(MSVC)  || COMPILER(SUNCC)) && !COMPILER(INTEL)
        unsigned char m_data[INT_MAX];
#else
        unsigned char m_data[];
#endif
    };
} // namespace WTF

using WTF::ByteArray;

#endif
