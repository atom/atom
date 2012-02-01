/*
 * Copyright (C) 2009 Joseph Pecoraro. All rights reserved.
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

#ifndef Cookie_h
#define Cookie_h

#include "PlatformString.h"
#include <wtf/text/StringHash.h>

namespace WebCore {

    // This struct is currently only used to provide more cookies information
    // to the Web Inspector.

    struct Cookie {
        Cookie(const String& name, const String& value, const String& domain,
                const String& path, double expires, bool httpOnly, bool secure,
                bool session)
            : name(name)
            , value(value)
            , domain(domain)
            , path(path)
            , expires(expires)
            , httpOnly(httpOnly)
            , secure(secure)
            , session(session)
        {
        }

        String name;
        String value;
        String domain;
        String path;
        double expires;
        bool httpOnly;
        bool secure;
        bool session;
    };

    struct CookieHash {
        static unsigned hash(Cookie key)
        { 
            return StringHash::hash(key.name) + StringHash::hash(key.domain) + StringHash::hash(key.path) + key.secure;
        }

        static bool equal(Cookie a, Cookie b)
        {
            return a.name == b.name && a.domain == b.domain && a.path == b.path && a.secure == b.secure;
        }
    };
}

namespace WTF {
    template<typename T> struct DefaultHash;
    template<> struct DefaultHash<WebCore::Cookie> {
        typedef WebCore::CookieHash Hash;
    };
}

#endif
