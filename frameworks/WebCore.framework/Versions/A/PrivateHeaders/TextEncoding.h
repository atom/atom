/*
 * Copyright (C) 2004, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef TextEncoding_h
#define TextEncoding_h

#include "TextCodec.h"
#include <wtf/Forward.h>
#include <wtf/unicode/Unicode.h>

namespace WebCore {

    class TextEncoding {
    public:
        TextEncoding() : m_name(0) { }
        TextEncoding(const char* name);
        TextEncoding(const String& name);

        bool isValid() const { return m_name; }
        const char* name() const { return m_name; }
        const char* domName() const; // name exposed via DOM
        bool usesVisualOrdering() const;
        bool isJapanese() const;
        
        PassRefPtr<StringImpl> displayString(PassRefPtr<StringImpl> str) const
        {
            if (m_backslashAsCurrencySymbol == '\\' || !str)
                return str;
            return str->replace('\\', m_backslashAsCurrencySymbol);
        }
        void displayBuffer(UChar* characters, unsigned len) const
        {
            if (m_backslashAsCurrencySymbol == '\\')
                return;
            for (unsigned i = 0; i < len; ++i) {
                if (characters[i] == '\\')
                    characters[i] = m_backslashAsCurrencySymbol;
            }
        }

        const TextEncoding& closestByteBasedEquivalent() const;
        const TextEncoding& encodingForFormSubmission() const;

        String decode(const char* str, size_t length) const
        {
            bool ignored;
            return decode(str, length, false, ignored);
        }
        String decode(const char*, size_t length, bool stopOnError, bool& sawError) const;
        CString encode(const UChar*, size_t length, UnencodableHandling) const;

        UChar backslashAsCurrencySymbol() const;

    private:
        bool isNonByteBasedEncoding() const;
        bool isUTF7Encoding() const;

        const char* m_name;
        UChar m_backslashAsCurrencySymbol;
    };

    inline bool operator==(const TextEncoding& a, const TextEncoding& b) { return a.name() == b.name(); }
    inline bool operator!=(const TextEncoding& a, const TextEncoding& b) { return a.name() != b.name(); }

    const TextEncoding& ASCIIEncoding();
    const TextEncoding& Latin1Encoding();
    const TextEncoding& UTF16BigEndianEncoding();
    const TextEncoding& UTF16LittleEndianEncoding();
    const TextEncoding& UTF32BigEndianEncoding();
    const TextEncoding& UTF32LittleEndianEncoding();
    const TextEncoding& UTF8Encoding();
    const TextEncoding& WindowsLatin1Encoding();

} // namespace WebCore

#endif // TextEncoding_h
