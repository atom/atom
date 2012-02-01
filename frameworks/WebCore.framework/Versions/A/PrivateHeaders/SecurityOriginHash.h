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

#ifndef SecurityOriginHash_h
#define SecurityOriginHash_h

#include "KURL.h"
#include "SecurityOrigin.h"
#include <wtf/RefPtr.h>

namespace WebCore {

struct SecurityOriginHash {
    static unsigned hash(SecurityOrigin* origin)
    {
        unsigned hashCodes[3] = {
            origin->protocol().impl() ? origin->protocol().impl()->hash() : 0,
            origin->host().impl() ? origin->host().impl()->hash() : 0,
            origin->port()
        };
        return StringHasher::hashMemory<sizeof(hashCodes)>(hashCodes);
    }
    static unsigned hash(const RefPtr<SecurityOrigin>& origin)
    {
        return hash(origin.get());
    }

    static bool equal(SecurityOrigin* a, SecurityOrigin* b)
    {
        // FIXME: The hash function above compares three specific fields.
        // This code to compare those three specific fields should be moved here from
        // SecurityOrigin as mentioned in SecurityOrigin.h so we don't accidentally change
        // equal without changing hash to match it.
        if (!a || !b)
            return a == b;
        return a->equal(b);
    }
    static bool equal(SecurityOrigin* a, const RefPtr<SecurityOrigin>& b)
    {
        return equal(a, b.get());
    }
    static bool equal(const RefPtr<SecurityOrigin>& a, SecurityOrigin* b)
    {
        return equal(a.get(), b);
    }
    static bool equal(const RefPtr<SecurityOrigin>& a, const RefPtr<SecurityOrigin>& b)
    {
        return equal(a.get(), b.get());
    }

    static const bool safeToCompareToEmptyOrDeleted = false;
};

} // namespace WebCore

#endif
