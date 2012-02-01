/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */
 
#ifndef IntRectHash_h
#define IntRectHash_h

#include "IntPointHash.h"
#include "IntRect.h"
#include "IntSizeHash.h"
#include <wtf/HashMap.h>
#include <wtf/HashSet.h>

namespace WTF {

template<> struct IntHash<WebCore::IntRect> {
    static unsigned hash(const WebCore::IntRect& key)
    {
        return intHash(static_cast<uint64_t>(DefaultHash<WebCore::IntPoint>::Hash::hash(key.location())) << 32 | DefaultHash<WebCore::IntSize>::Hash::hash(key.size()));
    }
    static bool equal(const WebCore::IntRect& a, const WebCore::IntRect& b)
    {
        return DefaultHash<WebCore::IntPoint>::Hash::equal(a.location(), b.location()) && DefaultHash<WebCore::IntSize>::Hash::equal(a.size(), b.size());
    }
    static const bool safeToCompareToEmptyOrDeleted = true;
};
template<> struct DefaultHash<WebCore::IntRect> { typedef IntHash<WebCore::IntRect> Hash; };

template<> struct HashTraits<WebCore::IntRect> : GenericHashTraits<WebCore::IntRect> {
    static const bool emptyValueIsZero = true;
    static const bool needsDestruction = false;
    static void constructDeletedValue(WebCore::IntRect& slot) { new (NotNull, &slot) WebCore::IntRect(-1, -1, -1, -1); }
    static bool isDeletedValue(const WebCore::IntRect& value) { return value.x() == -1 && value.y() == -1 && value.width() == -1 && value.height() == -1; }
};

}

#endif
