/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
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
 *
 */

#ifndef CrossOriginPreflightResultCache_h
#define CrossOriginPreflightResultCache_h

#include "KURLHash.h"
#include "ResourceHandle.h"
#include <wtf/HashMap.h>
#include <wtf/HashSet.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/text/StringHash.h>

namespace WebCore {

    class HTTPHeaderMap;
    class ResourceResponse;

    class CrossOriginPreflightResultCacheItem {
        WTF_MAKE_NONCOPYABLE(CrossOriginPreflightResultCacheItem); WTF_MAKE_FAST_ALLOCATED;
    public:
        CrossOriginPreflightResultCacheItem(StoredCredentials credentials)
            : m_absoluteExpiryTime(0)
            , m_credentials(credentials)
        {
        }

        bool parse(const ResourceResponse&, String& errorDescription);
        bool allowsCrossOriginMethod(const String&, String& errorDescription) const;
        bool allowsCrossOriginHeaders(const HTTPHeaderMap&, String& errorDescription) const;
        bool allowsRequest(StoredCredentials, const String& method, const HTTPHeaderMap& requestHeaders) const;

    private:
        typedef HashSet<String, CaseFoldingHash> HeadersSet;

        // FIXME: A better solution to holding onto the absolute expiration time might be
        // to start a timer for the expiration delta that removes this from the cache when
        // it fires.
        double m_absoluteExpiryTime;
        StoredCredentials m_credentials;
        HashSet<String> m_methods;
        HeadersSet m_headers;
    };

    class CrossOriginPreflightResultCache {
        WTF_MAKE_NONCOPYABLE(CrossOriginPreflightResultCache); WTF_MAKE_FAST_ALLOCATED;
    public:
        static CrossOriginPreflightResultCache& shared();

        void appendEntry(const String& origin, const KURL&, PassOwnPtr<CrossOriginPreflightResultCacheItem>);
        bool canSkipPreflight(const String& origin, const KURL&, StoredCredentials, const String& method, const HTTPHeaderMap& requestHeaders);

        void empty();

    private:
        CrossOriginPreflightResultCache() { }

        typedef HashMap<std::pair<String, KURL>, OwnPtr<CrossOriginPreflightResultCacheItem> > CrossOriginPreflightResultHashMap;

        CrossOriginPreflightResultHashMap m_preflightHashMap;
    };

} // namespace WebCore

#endif
