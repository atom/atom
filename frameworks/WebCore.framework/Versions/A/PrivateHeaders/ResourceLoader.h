/*
 * Copyright (C) 2005, 2006, 2011 Apple Inc. All rights reserved.
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

#ifndef ResourceLoader_h
#define ResourceLoader_h

#include "ResourceHandleClient.h"
#include "ResourceLoaderOptions.h"
#include "ResourceRequest.h"
#include "ResourceResponse.h"

#include <wtf/Forward.h>
#include <wtf/RefCounted.h>

namespace WebCore {

    class AuthenticationChallenge;
    class DocumentLoader;
    class Frame;
    class FrameLoader;
    class KURL;
    class ResourceHandle;
    class SharedBuffer;
    
    class ResourceLoader : public RefCounted<ResourceLoader>, protected ResourceHandleClient {
    public:
        virtual ~ResourceLoader();

        void cancel();

        virtual bool init(const ResourceRequest&);

        FrameLoader* frameLoader() const;
        DocumentLoader* documentLoader() const { return m_documentLoader.get(); }
        const ResourceRequest& originalRequest() const { return m_originalRequest; }
        
        virtual void cancel(const ResourceError&);
        ResourceError cancelledError();
        ResourceError blockedError();
        ResourceError cannotShowURLError();
        
        virtual void setDefersLoading(bool);

        void setIdentifier(unsigned long identifier) { m_identifier = identifier; }
        unsigned long identifier() const { return m_identifier; }

        virtual void releaseResources();
        const ResourceResponse& response() const;

        virtual void addData(const char*, int, bool allAtOnce);
        virtual PassRefPtr<SharedBuffer> resourceData();
        void clearResourceData();
        
        virtual void willSendRequest(ResourceRequest&, const ResourceResponse& redirectResponse);
        virtual void didSendData(unsigned long long bytesSent, unsigned long long totalBytesToBeSent);
        virtual void didReceiveResponse(const ResourceResponse&);
        virtual void didReceiveData(const char*, int, long long encodedDataLength, bool allAtOnce);
        virtual void didReceiveCachedMetadata(const char*, int) { }
        void willStopBufferingData(const char*, int);
        virtual void didFinishLoading(double finishTime);
        virtual void didFail(const ResourceError&);
#if HAVE(NETWORK_CFDATA_ARRAY_CALLBACK)
        virtual void didReceiveDataArray(CFArrayRef dataArray);
#endif

        virtual bool shouldUseCredentialStorage();
        virtual void didReceiveAuthenticationChallenge(const AuthenticationChallenge&);
        void didCancelAuthenticationChallenge(const AuthenticationChallenge&);
#if USE(PROTECTION_SPACE_AUTH_CALLBACK)
        virtual bool canAuthenticateAgainstProtectionSpace(const ProtectionSpace&);
#endif
        virtual void receivedCancellation(const AuthenticationChallenge&);

        // ResourceHandleClient
        virtual void willSendRequest(ResourceHandle*, ResourceRequest&, const ResourceResponse& redirectResponse);
        virtual void didSendData(ResourceHandle*, unsigned long long bytesSent, unsigned long long totalBytesToBeSent);
        virtual void didReceiveResponse(ResourceHandle*, const ResourceResponse&);
        virtual void didReceiveData(ResourceHandle*, const char*, int, int encodedDataLength);
        virtual void didReceiveCachedMetadata(ResourceHandle*, const char* data, int length) { didReceiveCachedMetadata(data, length); }
        virtual void didFinishLoading(ResourceHandle*, double finishTime);
        virtual void didFail(ResourceHandle*, const ResourceError&);
        virtual void wasBlocked(ResourceHandle*);
        virtual void cannotShowURL(ResourceHandle*);
        virtual void willStopBufferingData(ResourceHandle*, const char* data, int length) { willStopBufferingData(data, length); } 
        virtual bool shouldUseCredentialStorage(ResourceHandle*) { return shouldUseCredentialStorage(); }
        virtual void didReceiveAuthenticationChallenge(ResourceHandle*, const AuthenticationChallenge& challenge) { didReceiveAuthenticationChallenge(challenge); } 
        virtual void didCancelAuthenticationChallenge(ResourceHandle*, const AuthenticationChallenge& challenge) { didCancelAuthenticationChallenge(challenge); } 
#if HAVE(NETWORK_CFDATA_ARRAY_CALLBACK)
        virtual void didReceiveDataArray(ResourceHandle*, CFArrayRef dataArray);
#endif
#if USE(PROTECTION_SPACE_AUTH_CALLBACK)
        virtual bool canAuthenticateAgainstProtectionSpace(ResourceHandle*, const ProtectionSpace& protectionSpace) { return canAuthenticateAgainstProtectionSpace(protectionSpace); }
#endif
        virtual void receivedCancellation(ResourceHandle*, const AuthenticationChallenge& challenge) { receivedCancellation(challenge); }
        virtual void willCacheResponse(ResourceHandle*, CacheStoragePolicy&);
#if PLATFORM(MAC)
#if USE(CFNETWORK)
        virtual CFCachedURLResponseRef willCacheResponse(ResourceHandle*, CFCachedURLResponseRef);
#else
        virtual NSCachedURLResponse* willCacheResponse(ResourceHandle*, NSCachedURLResponse*);
#endif
#endif // PLATFORM(MAC)
#if PLATFORM(WIN) && USE(CFNETWORK)
        // FIXME: Windows should use willCacheResponse - <https://bugs.webkit.org/show_bug.cgi?id=57257>.
        virtual bool shouldCacheResponse(ResourceHandle*, CFCachedURLResponseRef);
#endif
#if PLATFORM(CHROMIUM)
        virtual void didDownloadData(ResourceHandle*, int);
        virtual void didDownloadData(int);
#endif
#if ENABLE(BLOB)
        virtual AsyncFileStream* createAsyncFileStream(FileStreamClient*);
#endif

        const KURL& url() const { return m_request.url(); } 
        ResourceHandle* handle() const { return m_handle.get(); }
        bool sendResourceLoadCallbacks() const { return m_options.sendLoadCallbacks; }

        bool reachedTerminalState() const { return m_reachedTerminalState; }

        void setShouldBufferData(DataBufferingPolicy);

    protected:
        ResourceLoader(Frame*, ResourceLoaderOptions);

        friend class ApplicationCacheHost;  // for access to request()
        friend class ResourceLoadScheduler; // for access to start()
        // start() actually sends the load to the network (unless the load is being 
        // deferred) and should only be called by ResourceLoadScheduler or setDefersLoading().
        void start();
        
        void didFinishLoadingOnePart(double finishTime);

        const ResourceRequest& request() const { return m_request; }
        bool cancelled() const { return m_cancelled; }
        bool defersLoading() const { return m_defersLoading; }

        RefPtr<ResourceHandle> m_handle;
        RefPtr<Frame> m_frame;
        RefPtr<DocumentLoader> m_documentLoader;
        ResourceResponse m_response;
        
    private:
        virtual void willCancel(const ResourceError&) = 0;
        virtual void didCancel(const ResourceError&) = 0;

        ResourceRequest m_request;
        ResourceRequest m_originalRequest; // Before redirects.
        RefPtr<SharedBuffer> m_resourceData;
        
        unsigned long m_identifier;

        bool m_reachedTerminalState;
        bool m_calledWillCancel;
        bool m_cancelled;
        bool m_calledDidFinishLoad;

        bool m_defersLoading;
        ResourceRequest m_deferredRequest;
        ResourceLoaderOptions m_options;
    };

inline const ResourceResponse& ResourceLoader::response() const
{
    return m_response;
}

}

#endif
