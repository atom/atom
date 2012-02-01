/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef CachedTranscendentalFunction_h
#define CachedTranscendentalFunction_h

#include "JSValue.h"

namespace JSC {

typedef double (*TranscendentalFunctionPtr)(double);

// CachedTranscendentalFunction provides a generic mechanism to cache results
// for pure functions with the signature "double func(double)", and where NaN
// maps to NaN.
template<TranscendentalFunctionPtr orignalFunction>
class CachedTranscendentalFunction {
    struct CacheEntry {
        double operand;
        double result;
    };

public:
    CachedTranscendentalFunction()
        : m_cache(0)
    {
    }

    ~CachedTranscendentalFunction()
    {
        if (m_cache)
            fastFree(m_cache);
    }

    JSValue operator() (double operand)
    {
        if (UNLIKELY(!m_cache))
            initialize();
        CacheEntry* entry = &m_cache[hash(operand)];

        if (entry->operand == operand)
            return jsDoubleNumber(entry->result);
        double result = orignalFunction(operand);
        entry->operand = operand;
        entry->result = result;
        return jsDoubleNumber(result);
    }

private:
    void initialize()
    {
        // Lazily allocate the table, populate with NaN->NaN mapping.
        m_cache = static_cast<CacheEntry*>(fastMalloc(s_cacheSize * sizeof(CacheEntry)));
        for (unsigned x = 0; x < s_cacheSize; ++x) {
            m_cache[x].operand = std::numeric_limits<double>::quiet_NaN();
            m_cache[x].result = std::numeric_limits<double>::quiet_NaN();
        }
    }

    static unsigned hash(double d)
    {
        union doubleAndUInt64 {
            double d;
            uint32_t is[2];
        } u;
        u.d = d;

        unsigned x = u.is[0] ^ u.is[1];
        x = (x >> 20) ^ (x >> 8);
        return x & (s_cacheSize - 1);
    }

    static const unsigned s_cacheSize = 0x1000;
    CacheEntry* m_cache;
};

}

#endif // CachedTranscendentalFunction_h
