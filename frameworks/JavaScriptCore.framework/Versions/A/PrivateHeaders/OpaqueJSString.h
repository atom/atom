/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
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

#ifndef OpaqueJSString_h
#define OpaqueJSString_h

#include <wtf/ThreadSafeRefCounted.h>
#include <runtime/UString.h>

namespace JSC {
    class Identifier;
    class JSGlobalData;
}

struct OpaqueJSString : public ThreadSafeRefCounted<OpaqueJSString> {

    static PassRefPtr<OpaqueJSString> create() // null
    {
        return adoptRef(new OpaqueJSString);
    }

    static PassRefPtr<OpaqueJSString> create(const UChar* characters, unsigned length)
    {
        return adoptRef(new OpaqueJSString(characters, length));
    }

    JS_EXPORT_PRIVATE static PassRefPtr<OpaqueJSString> create(const JSC::UString&);

    UChar* characters() { return this ? m_characters : 0; }
    unsigned length() { return this ? m_length : 0; }

    JSC::UString ustring() const;
    JSC::Identifier identifier(JSC::JSGlobalData*) const;

private:
    friend class WTF::ThreadSafeRefCounted<OpaqueJSString>;

    OpaqueJSString()
        : m_characters(0)
        , m_length(0)
    {
    }

    OpaqueJSString(const UChar* characters, unsigned length)
        : m_length(length)
    {
        m_characters = new UChar[length];
        memcpy(m_characters, characters, length * sizeof(UChar));
    }

    ~OpaqueJSString()
    {
        delete[] m_characters;
    }

    UChar* m_characters;
    unsigned m_length;
};

#endif
