/*
 * Copyright (C) 2005, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef NetscapePlugInStreamLoader_h
#define NetscapePlugInStreamLoader_h

#include "ResourceLoader.h"
#include <wtf/Forward.h>

namespace WebCore {

    class NetscapePlugInStreamLoader;

    class NetscapePlugInStreamLoaderClient {
    public:
        virtual void didReceiveResponse(NetscapePlugInStreamLoader*, const ResourceResponse&) = 0;
        virtual void didReceiveData(NetscapePlugInStreamLoader*, const char*, int) = 0;
        virtual void didFail(NetscapePlugInStreamLoader*, const ResourceError&) = 0;
        virtual void didFinishLoading(NetscapePlugInStreamLoader*) { }
        virtual bool wantsAllStreams() const { return false; }

    protected:
        virtual ~NetscapePlugInStreamLoaderClient() { }
    };

    class NetscapePlugInStreamLoader : public ResourceLoader {
    public:
        static PassRefPtr<NetscapePlugInStreamLoader> create(Frame*, NetscapePlugInStreamLoaderClient*, const ResourceRequest&);
        virtual ~NetscapePlugInStreamLoader();

        bool isDone() const;

    private:
        virtual void didReceiveResponse(const ResourceResponse&);
        virtual void didReceiveData(const char*, int, long long encodedDataLength, bool allAtOnce);
        virtual void didFinishLoading(double finishTime);
        virtual void didFail(const ResourceError&);

        virtual void releaseResources();

        NetscapePlugInStreamLoader(Frame*, NetscapePlugInStreamLoaderClient*);

        virtual void willCancel(const ResourceError&);
        virtual void didCancel(const ResourceError&);

        NetscapePlugInStreamLoaderClient* m_client;
    };

}

#endif // NetscapePlugInStreamLoader_h
