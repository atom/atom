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

#ifndef ThreadRestrictionVerifier_h
#define ThreadRestrictionVerifier_h

#include <wtf/Assertions.h>
#include <wtf/Threading.h>
#include <wtf/ThreadingPrimitives.h>

#if HAVE(DISPATCH_H)
#include <dispatch/dispatch.h>
#endif

#ifndef NDEBUG

namespace WTF {

// Verifies that a class is used in a way that respects its lack of thread-safety.
// The default mode is to verify that the object will only be used on a single thread. The
// thread gets captured when setShared(true) is called.
// The mode may be changed by calling useMutexMode (or turnOffVerification).
class ThreadRestrictionVerifier {
public:
    ThreadRestrictionVerifier()
        : m_mode(SingleThreadVerificationMode)
        , m_shared(false)
        , m_owningThread(0)
        , m_mutex(0)
#if HAVE(DISPATCH_H)
        , m_owningQueue(0)
#endif
    {
    }

#if HAVE(DISPATCH_H)
    ~ThreadRestrictionVerifier()
    {
        if (m_owningQueue)
            dispatch_release(m_owningQueue);
    }
#endif

    void setMutexMode(Mutex& mutex)
    {
        ASSERT(m_mode == SingleThreadVerificationMode || (m_mode == MutexVerificationMode && &mutex == m_mutex));
        m_mode = MutexVerificationMode;
        m_mutex = &mutex;
    }

#if HAVE(DISPATCH_H)
    void setDispatchQueueMode(dispatch_queue_t queue)
    {
        ASSERT(m_mode == SingleThreadVerificationMode);
        m_mode = SingleDispatchQueueVerificationMode;
        m_owningQueue = queue;
        dispatch_retain(m_owningQueue);
    }
#endif

    void turnOffVerification()
    {
        ASSERT(m_mode == SingleThreadVerificationMode);
        m_mode = NoVerificationMode;
    }

    // Indicates that the object may (or may not) be owned by more than one place.
    void setShared(bool shared)
    {
#if !ASSERT_DISABLED
        bool previouslyShared = m_shared;
#endif
        m_shared = shared;

        if (!m_shared)
            return;

        switch (m_mode) {
        case SingleThreadVerificationMode:
            ASSERT(shared != previouslyShared);
            // Capture the current thread to verify that subsequent ref/deref happen on this thread.
            m_owningThread = currentThread();
            return;

#if HAVE(DISPATCH_H)
        case SingleDispatchQueueVerificationMode:
#endif
        case MutexVerificationMode:
        case NoVerificationMode:
            return;
        }
        ASSERT_NOT_REACHED();
    }

    // Is it OK to use the object at this moment on the current thread?
    bool isSafeToUse() const
    {
        if (!m_shared)
            return true;

        switch (m_mode) {
        case SingleThreadVerificationMode:
            return m_owningThread == currentThread();

        case MutexVerificationMode:
            if (!m_mutex->tryLock())
                return true;
            m_mutex->unlock();
            return false;

#if HAVE(DISPATCH_H)
        case SingleDispatchQueueVerificationMode:
            return m_owningQueue == dispatch_get_current_queue();
#endif

        case NoVerificationMode:
            return true;
        }
        ASSERT_NOT_REACHED();
        return true;
    }

private:
    enum VerificationMode {
        SingleThreadVerificationMode,
        MutexVerificationMode,
        NoVerificationMode,
#if HAVE(DISPATCH_H)
        SingleDispatchQueueVerificationMode,
#endif
    };

    VerificationMode m_mode;
    bool m_shared;

    // Used by SingleThreadVerificationMode
    ThreadIdentifier m_owningThread;

    // Used by MutexVerificationMode.
    Mutex* m_mutex;

#if HAVE(DISPATCH_H)
    // Used by SingleDispatchQueueVerificationMode.
    dispatch_queue_t m_owningQueue;
#endif
};

}

#endif
#endif
