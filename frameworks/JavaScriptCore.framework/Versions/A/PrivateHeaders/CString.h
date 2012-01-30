/*
 * Copyright (C) 2003, 2006, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef CString_h
#define CString_h

#include "PassRefPtr.h"
#include "RefCounted.h"
#include "Vector.h"

namespace WTF {

class CStringBuffer : public RefCounted<CStringBuffer> {
public:
    const char* data() { return m_vector.data(); }
    size_t length() { return m_vector.size(); }

private:
    friend class CString;

    static PassRefPtr<CStringBuffer> create(size_t length) { return adoptRef(new CStringBuffer(length)); }
    CStringBuffer(size_t length) : m_vector(length) { }
    char* mutableData() { return m_vector.data(); }

    Vector<char> m_vector;
};

// A container for a null-terminated char array supporting copy-on-write
// assignment.  The contained char array may be null.
class CString {
public:
    CString() { }
    WTF_EXPORT_PRIVATE CString(const char*);
    WTF_EXPORT_PRIVATE CString(const char*, size_t length);
    CString(CStringBuffer* buffer) : m_buffer(buffer) { }
    WTF_EXPORT_PRIVATE static CString newUninitialized(size_t length, char*& characterBuffer);

    const char* data() const
    {
        return m_buffer ? m_buffer->data() : 0;
    }
    WTF_EXPORT_PRIVATE char* mutableData();
    size_t length() const
    {
        return m_buffer ? m_buffer->length() - 1 : 0;
    }

    bool isNull() const { return !m_buffer; }

    CStringBuffer* buffer() const { return m_buffer.get(); }

private:
    void copyBufferIfNeeded();
    void init(const char*, size_t length);
    RefPtr<CStringBuffer> m_buffer;
};

WTF_EXPORT_PRIVATE bool operator==(const CString& a, const CString& b);
inline bool operator!=(const CString& a, const CString& b) { return !(a == b); }

} // namespace WTF

using WTF::CString;

#endif // CString_h
