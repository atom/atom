/*
 * Copyright (C) 2007 Apple Inc.  All rights reserved.
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
#ifndef ProtectionSpace_h
#define ProtectionSpace_h

#include "PlatformString.h"

namespace WebCore {

enum ProtectionSpaceServerType {
    ProtectionSpaceServerHTTP = 1,
    ProtectionSpaceServerHTTPS = 2,
    ProtectionSpaceServerFTP = 3,
    ProtectionSpaceServerFTPS = 4,
    ProtectionSpaceProxyHTTP = 5,
    ProtectionSpaceProxyHTTPS = 6,
    ProtectionSpaceProxyFTP = 7,
    ProtectionSpaceProxySOCKS = 8
};

enum ProtectionSpaceAuthenticationScheme {
    ProtectionSpaceAuthenticationSchemeDefault = 1,
    ProtectionSpaceAuthenticationSchemeHTTPBasic = 2,
    ProtectionSpaceAuthenticationSchemeHTTPDigest = 3,
    ProtectionSpaceAuthenticationSchemeHTMLForm = 4,
    ProtectionSpaceAuthenticationSchemeNTLM = 5,
    ProtectionSpaceAuthenticationSchemeNegotiate = 6,
    ProtectionSpaceAuthenticationSchemeClientCertificateRequested = 7,
    ProtectionSpaceAuthenticationSchemeServerTrustEvaluationRequested = 8,
    ProtectionSpaceAuthenticationSchemeUnknown = 100
};
  
class ProtectionSpace {

public:
    ProtectionSpace();
    ProtectionSpace(const String& host, int port, ProtectionSpaceServerType, const String& realm, ProtectionSpaceAuthenticationScheme);

    // Hash table deleted values, which are only constructed and never copied or destroyed.
    ProtectionSpace(WTF::HashTableDeletedValueType) : m_isHashTableDeletedValue(true) { }
    bool isHashTableDeletedValue() const { return m_isHashTableDeletedValue; }
    
    const String& host() const;
    int port() const;
    ProtectionSpaceServerType serverType() const;
    bool isProxy() const;
    const String& realm() const;
    ProtectionSpaceAuthenticationScheme authenticationScheme() const;
    
    bool receivesCredentialSecurely() const;

private:
    String m_host;
    int m_port;
    ProtectionSpaceServerType m_serverType;
    String m_realm;
    ProtectionSpaceAuthenticationScheme m_authenticationScheme;
    bool m_isHashTableDeletedValue;
};

bool operator==(const ProtectionSpace& a, const ProtectionSpace& b);
inline bool operator!=(const ProtectionSpace& a, const ProtectionSpace& b) { return !(a == b); }
    
} // namespace WebCore

#endif // ProtectionSpace_h
