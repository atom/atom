/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef NavigationAction_h
#define NavigationAction_h

#include "Event.h"
#include "FrameLoaderTypes.h"
#include "KURL.h"
#include "ResourceRequest.h"
#include <wtf/Forward.h>

namespace WebCore {

    class NavigationAction {
    public:
        NavigationAction();
        NavigationAction(const ResourceRequest&);
        NavigationAction(const ResourceRequest&, NavigationType);
        NavigationAction(const ResourceRequest&, FrameLoadType, bool isFormSubmission);
        NavigationAction(const ResourceRequest&, NavigationType, PassRefPtr<Event>);
        NavigationAction(const ResourceRequest&, FrameLoadType, bool isFormSubmission, PassRefPtr<Event>);

        bool isEmpty() const { return m_resourceRequest.url().isEmpty(); }

        KURL url() const { return m_resourceRequest.url(); }
        const ResourceRequest& resourceRequest() const { return m_resourceRequest; }

        NavigationType type() const { return m_type; }
        const Event* event() const { return m_event.get(); }

    private:
        ResourceRequest m_resourceRequest;
        NavigationType m_type;
        RefPtr<Event> m_event;
    };

}

#endif
