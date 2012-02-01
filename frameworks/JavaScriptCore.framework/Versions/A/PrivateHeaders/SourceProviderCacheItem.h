/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef SourceProviderCacheItem_h
#define SourceProviderCacheItem_h

#include "ParserTokens.h"
#include <wtf/Vector.h>
#include <wtf/text/WTFString.h>

namespace JSC {

class SourceProviderCacheItem {
public:
    SourceProviderCacheItem(int closeBraceLine, int closeBracePos)
        : closeBraceLine(closeBraceLine) 
        , closeBracePos(closeBracePos)
    {
    }
    unsigned approximateByteSize() const
    {
        // The identifiers are uniqued strings so most likely there are few names that actually use any additional memory.
        static const unsigned assummedAverageIdentifierSize = sizeof(RefPtr<StringImpl>) + 2;
        unsigned size = sizeof(*this);
        size += usedVariables.size() * assummedAverageIdentifierSize;
        size += writtenVariables.size() * assummedAverageIdentifierSize;
        return size;
    }
    JSToken closeBraceToken() const 
    {
        JSToken token;
        token.m_type = CLOSEBRACE;
        token.m_data.intValue = closeBracePos;
        token.m_info.startOffset = closeBracePos;
        token.m_info.endOffset = closeBracePos + 1;
        token.m_info.line = closeBraceLine; 
        return token;
    }
    
    int closeBraceLine;
    int closeBracePos;
    bool usesEval;
    bool strictMode;
    bool needsFullActivation;
    Vector<RefPtr<StringImpl> > usedVariables;
    Vector<RefPtr<StringImpl> > writtenVariables;
};

}

#endif // SourceProviderCacheItem_h
