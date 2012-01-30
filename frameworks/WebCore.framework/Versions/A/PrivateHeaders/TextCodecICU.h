/*
 * Copyright (C) 2004, 2006, 2007, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Alexey Proskuryakov <ap@nypop.com>
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

#ifndef TextCodecICU_h
#define TextCodecICU_h

#include "TextCodec.h"
#include "TextEncoding.h"
#include <unicode/utypes.h>

typedef struct UConverter UConverter;

namespace WebCore {

    class TextCodecICU : public TextCodec {
    public:
        static void registerEncodingNames(EncodingNameRegistrar);
        static void registerCodecs(TextCodecRegistrar);

        virtual ~TextCodecICU();

    private:
        TextCodecICU(const TextEncoding&);
        static PassOwnPtr<TextCodec> create(const TextEncoding&, const void*);

        virtual String decode(const char*, size_t length, bool flush, bool stopOnError, bool& sawError);
        virtual CString encode(const UChar*, size_t length, UnencodableHandling);

        void createICUConverter() const;
        void releaseICUConverter() const;
        bool needsGBKFallbacks() const { return m_needsGBKFallbacks; }
        void setNeedsGBKFallbacks(bool needsFallbacks) { m_needsGBKFallbacks = needsFallbacks; }
        
        int decodeToBuffer(UChar* buffer, UChar* bufferLimit, const char*& source,
            const char* sourceLimit, int32_t* offsets, bool flush, UErrorCode& err);

        TextEncoding m_encoding;
        unsigned m_numBufferedBytes;
        unsigned char m_bufferedBytes[16]; // bigger than any single multi-byte character
        mutable UConverter* m_converterICU;
        mutable bool m_needsGBKFallbacks;
    };

    struct ICUConverterWrapper {
        ICUConverterWrapper() : converter(0) { }
        ~ICUConverterWrapper();

        UConverter* converter;

        WTF_MAKE_NONCOPYABLE(ICUConverterWrapper);
    };

} // namespace WebCore

#endif // TextCodecICU_h
