/*
 * Copyright (C) 2009 Apple Inc. All Rights Reserved.
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

#ifndef ProtectionSpaceHash_h
#define ProtectionSpaceHash_h

#include "ProtectionSpace.h"
#include <wtf/HashTraits.h>

namespace WebCore {

struct ProtectionSpaceHash {
    static unsigned hash(const ProtectionSpace& protectionSpace)
    { 
        unsigned hashCodes[5] = {
            protectionSpace.host().impl() ? protectionSpace.host().impl()->hash() : 0, 
            protectionSpace.port(), 
            protectionSpace.serverType(),
            protectionSpace.authenticationScheme(),
            protectionSpace.realm().impl() ? protectionSpace.realm().impl()->hash() : 0
        };

        unsigned codeCount = sizeof(hashCodes);
        // Ignore realm for proxies.
        if (protectionSpace.isProxy())
            codeCount -= sizeof(hashCodes[0]);
        return StringHasher::hashMemory(hashCodes, codeCount);
    }
    
    static bool equal(const ProtectionSpace& a, const ProtectionSpace& b) { return a == b; }
    static const bool safeToCompareToEmptyOrDeleted = false;
};

} // namespace WebCore

namespace WTF {

    template<> struct HashTraits<WebCore::ProtectionSpace> : SimpleClassHashTraits<WebCore::ProtectionSpace> { };

    template<typename T> struct DefaultHash;
    template<> struct DefaultHash<WebCore::ProtectionSpace> {
        typedef WebCore::ProtectionSpaceHash Hash;
    };

} // namespace WTF


#endif // ProtectionSpaceHash_h
