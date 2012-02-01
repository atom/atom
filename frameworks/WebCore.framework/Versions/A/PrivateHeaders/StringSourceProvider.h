/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef StringSourceProvider_h
#define StringSourceProvider_h

#include "JSDOMBinding.h"
#include "ScriptSourceProvider.h"
#include <parser/SourceCode.h>

namespace WebCore {

    class StringSourceProvider : public ScriptSourceProvider {
    public:
        static PassRefPtr<StringSourceProvider> create(const String& source, const String& url, const TextPosition& startPosition)
        {
            return adoptRef(new StringSourceProvider(source, url, startPosition));
        }

        JSC::UString getRange(int start, int end) const { return JSC::UString(m_source.characters() + start, end - start); }
        const StringImpl* data() const { return m_source.impl(); }
        int length() const { return m_source.length(); }
        const String& source() const { return m_source; }

    private:
        StringSourceProvider(const String& source, const String& url, const TextPosition& startPosition)
            : ScriptSourceProvider(stringToUString(url), startPosition)
            , m_source(source)
        {
        }
        
        String m_source;
    };

    inline JSC::SourceCode makeSource(const String& source, const String& url = String(), const TextPosition& startPosition = TextPosition::minimumPosition())
    {
        return JSC::SourceCode(StringSourceProvider::create(source, url, startPosition), startPosition.m_line.oneBasedInt());
    }

} // namespace WebCore

#endif // StringSourceProvider_h
