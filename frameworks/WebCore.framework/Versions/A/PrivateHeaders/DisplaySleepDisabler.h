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

#ifndef DisplaySleepDisabler_h
#define DisplaySleepDisabler_h

#include <wtf/Noncopyable.h>
#include <wtf/PassOwnPtr.h>

#ifdef BUILDING_ON_LEOPARD
#include "Timer.h"
#endif

namespace WebCore {

class DisplaySleepDisabler {
    WTF_MAKE_NONCOPYABLE(DisplaySleepDisabler);
public:
    static PassOwnPtr<DisplaySleepDisabler> create(const char* reason) { return adoptPtr(new DisplaySleepDisabler(reason)); }
    ~DisplaySleepDisabler();
    
private:
    DisplaySleepDisabler(const char* reason);

#ifdef BUILDING_ON_LEOPARD
    void systemActivityTimerFired(Timer<DisplaySleepDisabler>*);
#endif
    
    uint32_t m_disableDisplaySleepAssertion;
#ifdef BUILDING_ON_LEOPARD
    Timer<DisplaySleepDisabler> m_systemActivityTimer;
#endif
};

}

#endif // DisplaySleepDisabler_h
