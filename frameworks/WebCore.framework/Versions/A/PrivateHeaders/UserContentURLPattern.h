/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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
 
#ifndef UserContentURLPattern_h
#define UserContentURLPattern_h

#include "PlatformString.h"
#include <wtf/Vector.h>

namespace WebCore {

class KURL;

class UserContentURLPattern {
public:
    UserContentURLPattern() : m_invalid(true), m_matchSubdomains(false) { }

    UserContentURLPattern(const String& pattern)
    : m_matchSubdomains(false)
    {
        m_invalid = !parse(pattern);
    }

    bool isValid() const { return !m_invalid; }

    bool matches(const KURL&) const;

    const String& scheme() const { return m_scheme; }
    const String& host() const { return m_host; }
    const String& path() const { return m_path; }

    bool matchSubdomains() const { return m_matchSubdomains; }
    
    static bool matchesPatterns(const KURL&, const Vector<String>* whitelist, const Vector<String>* blacklist);

private:
    bool parse(const String& pattern);

    bool matchesHost(const KURL&) const;
    bool matchesPath(const KURL&) const;

    bool m_invalid;

    String m_scheme;
    String m_host;
    String m_path;

    bool m_matchSubdomains;
};


} // namespace WebCore

#endif // UserContentURLPattern_h
