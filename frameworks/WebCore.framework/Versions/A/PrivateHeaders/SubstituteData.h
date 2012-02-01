/*
 * Copyright (C) 2007 Apple Inc.  All rights reserved.
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

#ifndef SubstituteData_h
#define SubstituteData_h

#include "KURL.h"
#include "SharedBuffer.h"
#include "PlatformString.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

    class SubstituteData {
    public:
        SubstituteData() { }

        SubstituteData(PassRefPtr<SharedBuffer> content, const String& mimeType, const String& textEncoding, const KURL& failingURL, const KURL& responseURL = KURL())
            : m_content(content)
            , m_mimeType(mimeType)
            , m_textEncoding(textEncoding)
            , m_failingURL(failingURL)
            , m_responseURL(responseURL)
        {
        }

        bool isValid() const { return m_content != 0; }

        const SharedBuffer* content() const { return m_content.get(); }
        const String& mimeType() const { return m_mimeType; }
        const String& textEncoding() const { return m_textEncoding; }
        const KURL& failingURL() const { return m_failingURL; }
        const KURL& responseURL() const { return m_responseURL; }
        
    private:
        RefPtr<SharedBuffer> m_content;
        String m_mimeType;
        String m_textEncoding;
        KURL m_failingURL;
        KURL m_responseURL;
    };

}

#endif // SubstituteData_h

