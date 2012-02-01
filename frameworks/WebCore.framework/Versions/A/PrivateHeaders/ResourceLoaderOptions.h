/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
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

#ifndef ResourceLoaderOptions_h
#define ResourceLoaderOptions_h

#include "ResourceHandle.h"

namespace WebCore {
    
enum SendCallbackPolicy {
    SendCallbacks,
    DoNotSendCallbacks
};

enum ContentSniffingPolicy {
    SniffContent,
    DoNotSniffContent
};

enum DataBufferingPolicy {
    BufferData,
    DoNotBufferData
};

enum ClientCrossOriginCredentialPolicy {
    AskClientForCrossOriginCredentials,
    DoNotAskClientForCrossOriginCredentials
};

enum SecurityCheckPolicy {
    SkipSecurityCheck,
    DoSecurityCheck
};

struct ResourceLoaderOptions {
    ResourceLoaderOptions() : sendLoadCallbacks(DoNotSendCallbacks), sniffContent(DoNotSniffContent), shouldBufferData(BufferData), allowCredentials(DoNotAllowStoredCredentials), crossOriginCredentialPolicy(DoNotAskClientForCrossOriginCredentials), securityCheck(DoSecurityCheck) { }
    ResourceLoaderOptions(SendCallbackPolicy sendLoadCallbacks, ContentSniffingPolicy sniffContent, DataBufferingPolicy shouldBufferData, StoredCredentials allowCredentials, ClientCrossOriginCredentialPolicy crossOriginCredentialPolicy, SecurityCheckPolicy securityCheck)
        : sendLoadCallbacks(sendLoadCallbacks)
        , sniffContent(sniffContent)
        , shouldBufferData(shouldBufferData)
        , allowCredentials(allowCredentials)
        , crossOriginCredentialPolicy(crossOriginCredentialPolicy)
        , securityCheck(securityCheck)
    {
    }
    SendCallbackPolicy sendLoadCallbacks;
    ContentSniffingPolicy sniffContent;
    DataBufferingPolicy shouldBufferData;
    StoredCredentials allowCredentials; // Whether HTTP credentials and cookies are sent with the request.
    ClientCrossOriginCredentialPolicy crossOriginCredentialPolicy; // Whether we will ask the client for credentials (if we allow credentials at all).
    SecurityCheckPolicy securityCheck;
};

} // namespace WebCore    

#endif // ResourceLoaderOptions_h
