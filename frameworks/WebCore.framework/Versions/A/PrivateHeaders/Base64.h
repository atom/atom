/*
 * Copyright (C) 2006 Alexey Proskuryakov <ap@webkit.org>
 * Copyright (C) 2010 Patrick Gansterer <paroga@paroga.com>
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

#ifndef Base64_h
#define Base64_h

#include <wtf/Vector.h>
#include <wtf/text/CString.h>
#include <wtf/text/WTFString.h>

namespace WebCore {

enum Base64DecodePolicy { FailOnInvalidCharacter, IgnoreWhitespace, IgnoreInvalidCharacters };

void base64Encode(const char*, unsigned, Vector<char>&, bool insertLFs = false);
void base64Encode(const Vector<char>&, Vector<char>&, bool insertLFs = false);
void base64Encode(const CString&, Vector<char>&, bool insertLFs = false);
String base64Encode(const char*, unsigned, bool insertLFs = false);
String base64Encode(const Vector<char>&, bool insertLFs = false);
String base64Encode(const CString&, bool insertLFs = false);

bool base64Decode(const String&, Vector<char>&, Base64DecodePolicy = FailOnInvalidCharacter);
bool base64Decode(const Vector<char>&, Vector<char>&, Base64DecodePolicy = FailOnInvalidCharacter);
bool base64Decode(const char*, unsigned, Vector<char>&, Base64DecodePolicy = FailOnInvalidCharacter);

inline void base64Encode(const Vector<char>& in, Vector<char>& out, bool insertLFs)
{
    base64Encode(in.data(), in.size(), out, insertLFs);
}

inline void base64Encode(const CString& in, Vector<char>& out, bool insertLFs)
{
    base64Encode(in.data(), in.length(), out, insertLFs);
}

inline String base64Encode(const Vector<char>& in, bool insertLFs)
{
    return base64Encode(in.data(), in.size(), insertLFs);
}

inline String base64Encode(const CString& in, bool insertLFs)
{
    return base64Encode(in.data(), in.length(), insertLFs);
}

} // namespace WebCore

#endif // Base64_h
