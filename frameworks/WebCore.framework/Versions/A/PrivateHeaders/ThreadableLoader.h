/*
 * Copyright (C) 2009 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ThreadableLoader_h
#define ThreadableLoader_h

#include "ResourceHandle.h"
#include "ResourceLoaderOptions.h"
#include "SecurityOrigin.h"
#include <wtf/Noncopyable.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

    class ResourceError;
    class ResourceRequest;
    class ResourceResponse;
    class ScriptExecutionContext;
    class ThreadableLoaderClient;
    
    enum CrossOriginRequestPolicy {
        DenyCrossOriginRequests,
        UseAccessControl,
        AllowCrossOriginRequests
    };

    enum PreflightPolicy {
        ConsiderPreflight,
        ForcePreflight,
        PreventPreflight
    };

    struct ThreadableLoaderOptions : public ResourceLoaderOptions {
        ThreadableLoaderOptions() : preflightPolicy(ConsiderPreflight), crossOriginRequestPolicy(DenyCrossOriginRequests) { }
        PreflightPolicy preflightPolicy; // If AccessControl is used, how to determine if a preflight is needed.
        CrossOriginRequestPolicy crossOriginRequestPolicy;
        RefPtr<SecurityOrigin> securityOrigin;
    };

    // Useful for doing loader operations from any thread (not threadsafe, 
    // just able to run on threads other than the main thread).
    class ThreadableLoader {
        WTF_MAKE_NONCOPYABLE(ThreadableLoader);
    public:
        static void loadResourceSynchronously(ScriptExecutionContext*, const ResourceRequest&, ThreadableLoaderClient&, const ThreadableLoaderOptions&);
        static PassRefPtr<ThreadableLoader> create(ScriptExecutionContext*, ThreadableLoaderClient*, const ResourceRequest&, const ThreadableLoaderOptions&);

        virtual void cancel() = 0;
        void ref() { refThreadableLoader(); }
        void deref() { derefThreadableLoader(); }

    protected:
        ThreadableLoader() { }
        virtual ~ThreadableLoader() { }
        virtual void refThreadableLoader() = 0;
        virtual void derefThreadableLoader() = 0;
    };

} // namespace WebCore

#endif // ThreadableLoader_h
