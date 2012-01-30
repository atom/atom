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
 
#ifndef UserStyleSheet_h
#define UserStyleSheet_h

#include "KURL.h"
#include "UserContentTypes.h"
#include "UserStyleSheetTypes.h"
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

class UserStyleSheet {
    WTF_MAKE_NONCOPYABLE(UserStyleSheet); WTF_MAKE_FAST_ALLOCATED;
public:
    UserStyleSheet(const String& source, const KURL& url,
                   PassOwnPtr<Vector<String> > whitelist, PassOwnPtr<Vector<String> > blacklist,
                   UserContentInjectedFrames injectedFrames, UserStyleLevel level)
        : m_source(source)
        , m_url(url)
        , m_whitelist(whitelist)
        , m_blacklist(blacklist)
        , m_injectedFrames(injectedFrames)
        , m_level(level)
    {
    }

    const String& source() const { return m_source; }
    const KURL& url() const { return m_url; }
    const Vector<String>* whitelist() const { return m_whitelist.get(); }
    const Vector<String>* blacklist() const { return m_blacklist.get(); }
    UserContentInjectedFrames injectedFrames() const { return m_injectedFrames; }
    UserStyleLevel level() const { return m_level; }

private:
    String m_source;
    KURL m_url;
    OwnPtr<Vector<String> > m_whitelist;
    OwnPtr<Vector<String> > m_blacklist;
    UserContentInjectedFrames m_injectedFrames;
    UserStyleLevel m_level;
};

} // namespace WebCore
 
#endif // UserStyleSheet_h
