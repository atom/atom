/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef ResourceHandleClient_h
#define ResourceHandleClient_h

#include <wtf/CurrentTime.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

#if USE(CFNETWORK)
#include <CFNetwork/CFURLCachePriv.h>
#include <CFNetwork/CFURLResponsePriv.h>
#endif

#if PLATFORM(WIN) && USE(CFNETWORK)
#include <ConditionalMacros.h>
#endif

#if PLATFORM(MAC)
OBJC_CLASS NSCachedURLResponse;
#endif

namespace WebCore {
    class AsyncFileStream;
    class AuthenticationChallenge;
    class Credential;
    class FileStreamClient;
    class KURL;
    class ProtectionSpace;
    class ResourceHandle;
    class ResourceError;
    class ResourceRequest;
    class ResourceResponse;

    enum CacheStoragePolicy {
        StorageAllowed,
        StorageAllowedInMemoryOnly,
        StorageNotAllowed
    };
    
    class ResourceHandleClient {
    public:
        virtual ~ResourceHandleClient() { }

        // request may be modified
        virtual void willSendRequest(ResourceHandle*, ResourceRequest&, const ResourceResponse& /*redirectResponse*/) { }
        virtual void didSendData(ResourceHandle*, unsigned long long /*bytesSent*/, unsigned long long /*totalBytesToBeSent*/) { }

        virtual void didReceiveResponse(ResourceHandle*, const ResourceResponse&) { }
        virtual void didReceiveData(ResourceHandle*, const char*, int, int /*encodedDataLength*/) { }
        virtual void didReceiveCachedMetadata(ResourceHandle*, const char*, int) { }
        virtual void didFinishLoading(ResourceHandle*, double /*finishTime*/) { }
        virtual void didFail(ResourceHandle*, const ResourceError&) { }
        virtual void wasBlocked(ResourceHandle*) { }
        virtual void cannotShowURL(ResourceHandle*) { }

#if HAVE(NETWORK_CFDATA_ARRAY_CALLBACK)
        virtual bool supportsDataArray() { return false; }
        virtual void didReceiveDataArray(ResourceHandle*, CFArrayRef) { }
#endif

        virtual void willCacheResponse(ResourceHandle*, CacheStoragePolicy&) { }

        virtual bool shouldUseCredentialStorage(ResourceHandle*) { return false; }
        virtual void didReceiveAuthenticationChallenge(ResourceHandle*, const AuthenticationChallenge&) { }
        virtual void didCancelAuthenticationChallenge(ResourceHandle*, const AuthenticationChallenge&) { }
#if USE(PROTECTION_SPACE_AUTH_CALLBACK)
        virtual bool canAuthenticateAgainstProtectionSpace(ResourceHandle*, const ProtectionSpace&) { return false; }
#endif
        virtual void receivedCancellation(ResourceHandle*, const AuthenticationChallenge&) { }

#if PLATFORM(MAC)
#if USE(CFNETWORK)
        virtual CFCachedURLResponseRef willCacheResponse(ResourceHandle*, CFCachedURLResponseRef response) { return response; }
#else
        virtual NSCachedURLResponse* willCacheResponse(ResourceHandle*, NSCachedURLResponse* response) { return response; }
#endif
        virtual void willStopBufferingData(ResourceHandle*, const char*, int) { }
#endif // PLATFORM(MAC)
#if PLATFORM(WIN) && USE(CFNETWORK)
        virtual bool shouldCacheResponse(ResourceHandle*, CFCachedURLResponseRef) { return true; }
#endif
#if PLATFORM(CHROMIUM)
        virtual void didDownloadData(ResourceHandle*, int /*dataLength*/) { }
#endif
#if ENABLE(BLOB)
        virtual AsyncFileStream* createAsyncFileStream(FileStreamClient*) { return 0; }
#endif
    };

}

#endif
