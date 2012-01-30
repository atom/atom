/*
 * Copyright (C) 2010 Google, Inc. All Rights Reserved.
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

#ifndef ResourceLoadTiming_h
#define ResourceLoadTiming_h

#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class DocumentLoadTiming;

class ResourceLoadTiming : public RefCounted<ResourceLoadTiming> {
public:
    static PassRefPtr<ResourceLoadTiming> create()
    {
        return adoptRef(new ResourceLoadTiming);
    }

    PassRefPtr<ResourceLoadTiming> deepCopy()
    {
        RefPtr<ResourceLoadTiming> timing = create();
        timing->requestTime = requestTime;
        timing->proxyStart = proxyStart;
        timing->proxyEnd = proxyEnd;
        timing->dnsStart = dnsStart;
        timing->dnsEnd = dnsEnd;
        timing->connectStart = connectStart;
        timing->connectEnd = connectEnd;
        timing->sendStart = sendStart;
        timing->sendEnd = sendEnd;
        timing->receiveHeadersEnd = receiveHeadersEnd;
        timing->sslStart = sslStart;
        timing->sslEnd = sslEnd;
        return timing.release();
    }

    bool operator==(const ResourceLoadTiming& other) const
    {
        return requestTime == other.requestTime
            && proxyStart == other.proxyStart
            && proxyEnd == other.proxyEnd
            && dnsStart == other.dnsStart
            && dnsEnd == other.dnsEnd
            && connectStart == other.connectStart
            && connectEnd == other.connectEnd
            && sendStart == other.sendStart
            && sendEnd == other.sendEnd
            && receiveHeadersEnd == other.receiveHeadersEnd
            && sslStart == other.sslStart
            && sslEnd == other.sslEnd;
    }

    bool operator!=(const ResourceLoadTiming& other) const
    {
        return !(*this == other);
    }

    // We want to present a unified timeline to Javascript. Using walltime is problematic, because the clock may skew while resources
    // load. To prevent that skew, we record a single reference walltime when root document navigation begins. All other times are
    // recorded using monotonicallyIncreasingTime(). When a time needs to be presented to Javascript, we build a pseudo-walltime
    // using the following equation:
    //   pseudo time = document wall reference + (resource request time - document monotonic reference) + deltaMilliseconds / 1000.0.
    double convertResourceLoadTimeToDocumentTime(const DocumentLoadTiming* documentTiming, int deltaMilliseconds) const;

    double requestTime; // monotonicallyIncreasingTime() when the port started handling this request.
    int proxyStart; // The rest of these are millisecond deltas, using monotonicallyIncreasingTime(), from requestTime.
    int proxyEnd;
    int dnsStart;
    int dnsEnd;
    int connectStart;
    int connectEnd;
    int sendStart;
    int sendEnd;
    int receiveHeadersEnd;
    int sslStart;
    int sslEnd;

private:
    ResourceLoadTiming()
        : requestTime(0)
        , proxyStart(-1)
        , proxyEnd(-1)
        , dnsStart(-1)
        , dnsEnd(-1)
        , connectStart(-1)
        , connectEnd(-1)
        , sendStart(0)
        , sendEnd(0)
        , receiveHeadersEnd(0)
        , sslStart(-1)
        , sslEnd(-1)
    {
    }
};

}

#endif
