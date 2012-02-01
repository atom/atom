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
#ifndef Credential_h
#define Credential_h

#include "PlatformString.h"

#define CERTIFICATE_CREDENTIALS_SUPPORTED ((PLATFORM(MAC) || PLATFORM(IOS)) && !defined(BUILDING_ON_LEOPARD))

#if CERTIFICATE_CREDENTIALS_SUPPORTED
#include <Security/SecBase.h>
#include <wtf/RetainPtr.h>
#endif

namespace WebCore {

enum CredentialPersistence {
    CredentialPersistenceNone,
    CredentialPersistenceForSession,
    CredentialPersistencePermanent
};

#if CERTIFICATE_CREDENTIALS_SUPPORTED
enum CredentialType {
    CredentialTypePassword,
    CredentialTypeClientCertificate
};
#endif

class Credential {

public:
    Credential();
    Credential(const String& user, const String& password, CredentialPersistence);
    Credential(const Credential& original, CredentialPersistence);
#if CERTIFICATE_CREDENTIALS_SUPPORTED
    Credential(SecIdentityRef identity, CFArrayRef certificates, CredentialPersistence);
#endif
    
    bool isEmpty() const;
    
    const String& user() const;
    const String& password() const;
    bool hasPassword() const;
    CredentialPersistence persistence() const;
    
#if CERTIFICATE_CREDENTIALS_SUPPORTED
    SecIdentityRef identity() const;
    CFArrayRef certificates() const;
    CredentialType type() const;
#endif    
    
private:
    String m_user;
    String m_password;
    CredentialPersistence m_persistence;
#if CERTIFICATE_CREDENTIALS_SUPPORTED
    RetainPtr<SecIdentityRef> m_identity;
    RetainPtr<CFArrayRef> m_certificates;
    CredentialType m_type;
#endif
};

bool operator==(const Credential& a, const Credential& b);
inline bool operator!=(const Credential& a, const Credential& b) { return !(a == b); }
    
};
#endif
