/*
 * Copyright (C) 2010 Google Inc. All Rights Reserved.
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
 *
 */

#ifndef DocumentEventQueue_h
#define DocumentEventQueue_h

#include "EventQueue.h"
#include <wtf/HashSet.h>
#include <wtf/ListHashSet.h>
#include <wtf/OwnPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class Event;
class DocumentEventQueueTimer;
class Node;
class ScriptExecutionContext;

class DocumentEventQueue : public RefCounted<DocumentEventQueue>, public EventQueue {
public:
    enum ScrollEventTargetType {
        ScrollEventDocumentTarget,
        ScrollEventElementTarget
    };

    static PassRefPtr<DocumentEventQueue> create(ScriptExecutionContext*);
    virtual ~DocumentEventQueue();

    // EventQueue
    virtual bool enqueueEvent(PassRefPtr<Event>) OVERRIDE;
    virtual bool cancelEvent(Event*) OVERRIDE;
    virtual void close() OVERRIDE;

    void enqueueOrDispatchScrollEvent(PassRefPtr<Node>, ScrollEventTargetType);

private:
    explicit DocumentEventQueue(ScriptExecutionContext*);

    void pendingEventTimerFired();
    void dispatchEvent(PassRefPtr<Event>);

    OwnPtr<DocumentEventQueueTimer> m_pendingEventTimer;
    ListHashSet<RefPtr<Event> > m_queuedEvents;
    HashSet<Node*> m_nodesWithQueuedScrollEvents;
    bool m_isClosed;

    friend class DocumentEventQueueTimer;    
};

}

#endif // DocumentEventQueue_h
