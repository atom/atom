/*
 * Copyright (C) 2008 Google Inc. All rights reserved.
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

#ifndef LinkHash_h
#define LinkHash_h

#include <wtf/Forward.h>
#include <wtf/text/StringHash.h>

namespace WebCore {

class KURL;

typedef uint64_t LinkHash;

// Use the low 32-bits of the 64-bit LinkHash as the key for HashSets.
struct LinkHashHash {
    static unsigned hash(LinkHash key) { return static_cast<unsigned>(key); }
    static bool equal(LinkHash a, LinkHash b) { return a == b; }
    static const bool safeToCompareToEmptyOrDeleted = true;

    // See AlreadyHashed::avoidDeletedValue.
    static unsigned avoidDeletedValue(LinkHash hash64)
    {
        ASSERT(hash64);
        unsigned hash = static_cast<unsigned>(hash64);
        unsigned newHash = hash | (!(hash + 1) << 31);
        ASSERT(newHash);
        ASSERT(newHash != 0xFFFFFFFF);
        return newHash;
    }
};

// Returns the has of the string that will be used for visited link coloring.
LinkHash visitedLinkHash(const UChar* url, unsigned length);

// Resolves the potentially relative URL "attributeURL" relative to the given
// base URL, and returns the hash of the string that will be used for visited
// link coloring. It will return the special value of 0 if attributeURL does not
// look like a relative URL.
LinkHash visitedLinkHash(const KURL& base, const AtomicString& attributeURL);

// Resolves the potentially relative URL "attributeURL" relative to the given
// base URL, and returns the hash of the string that will be used for visited.
// It will return an empty Vector in case of errors.
void visitedURL(const KURL& base, const AtomicString& attributeURL, Vector<UChar, 512>&);


}  // namespace WebCore

#endif  // LinkHash_h
