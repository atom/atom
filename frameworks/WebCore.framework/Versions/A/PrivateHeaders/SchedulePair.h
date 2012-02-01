/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
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

#ifndef SchedulePair_h
#define SchedulePair_h

#include "PlatformString.h"
#include <wtf/HashSet.h>
#include <wtf/RefCounted.h>
#include <wtf/RetainPtr.h>

#if PLATFORM(MAC)
OBJC_CLASS NSRunLoop;
#endif

namespace WebCore {

class SchedulePair : public RefCounted<SchedulePair> {
public:
    static PassRefPtr<SchedulePair> create(CFRunLoopRef runLoop, CFStringRef mode) { return adoptRef(new SchedulePair(runLoop, mode)); }

#if PLATFORM(MAC) && !USE(CFNETWORK)
    static PassRefPtr<SchedulePair> create(NSRunLoop* runLoop, CFStringRef mode) { return adoptRef(new SchedulePair(runLoop, mode)); }
    NSRunLoop* nsRunLoop() const { return m_nsRunLoop.get(); }
#endif

    CFRunLoopRef runLoop() const { return m_runLoop.get(); }
    CFStringRef mode() const { return m_mode.get(); }

    bool operator==(const SchedulePair& other) const;

private:
    SchedulePair(CFRunLoopRef, CFStringRef);

#if PLATFORM(MAC) && !USE(CFNETWORK)
    SchedulePair(NSRunLoop*, CFStringRef);
    RetainPtr<NSRunLoop*> m_nsRunLoop;
#endif

    RetainPtr<CFRunLoopRef> m_runLoop;
    RetainPtr<CFStringRef> m_mode;
};

struct SchedulePairHash {
    static unsigned hash(const RefPtr<SchedulePair>& pair)
    {
        uintptr_t hashCodes[2] = { reinterpret_cast<uintptr_t>(pair->runLoop()), pair->mode() ? CFHash(pair->mode()) : 0 };
        return StringHasher::hashMemory<sizeof(hashCodes)>(hashCodes);
    }

    static bool equal(const RefPtr<SchedulePair>& a, const RefPtr<SchedulePair>& b) { return a == b; }

    static const bool safeToCompareToEmptyOrDeleted = true;
};

typedef HashSet<RefPtr<SchedulePair>, SchedulePairHash> SchedulePairHashSet;

} // namespace WebCore

#endif
