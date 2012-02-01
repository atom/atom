/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
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

#ifndef WorkerThread_h
#define WorkerThread_h

#if ENABLE(WORKERS)

#include "ContentSecurityPolicy.h"
#include "WorkerRunLoop.h"
#include <wtf/Forward.h>
#include <wtf/OwnPtr.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>

namespace WebCore {

    class KURL;
    class NotificationPresenter;
    class WorkerContext;
    class WorkerLoaderProxy;
    class WorkerReportingProxy;
    struct WorkerThreadStartupData;

    enum WorkerThreadStartMode { DontPauseWorkerContextOnStart, PauseWorkerContextOnStart };

    class WorkerThread : public RefCounted<WorkerThread> {
    public:
        virtual ~WorkerThread();

        bool start();
        void stop();

        ThreadIdentifier threadID() const { return m_threadID; }
        WorkerRunLoop& runLoop() { return m_runLoop; }
        WorkerLoaderProxy& workerLoaderProxy() const { return m_workerLoaderProxy; }
        WorkerReportingProxy& workerReportingProxy() const { return m_workerReportingProxy; }

        // Number of active worker threads.
        static unsigned workerThreadCount();

#if ENABLE(NOTIFICATIONS)
        NotificationPresenter* getNotificationPresenter() { return m_notificationPresenter; }
        void setNotificationPresenter(NotificationPresenter* presenter) { m_notificationPresenter = presenter; }
#endif

    protected:
        WorkerThread(const KURL&, const String& userAgent, const String& sourceCode, WorkerLoaderProxy&, WorkerReportingProxy&, WorkerThreadStartMode, const String& contentSecurityPolicy, ContentSecurityPolicy::HeaderType);

        // Factory method for creating a new worker context for the thread.
        virtual PassRefPtr<WorkerContext> createWorkerContext(const KURL&, const String& userAgent, const String& contentSecurityPolicy, ContentSecurityPolicy::HeaderType) = 0;

        // Executes the event loop for the worker thread. Derived classes can override to perform actions before/after entering the event loop.
        virtual void runEventLoop();

        WorkerContext* workerContext() { return m_workerContext.get(); }

    private:
        // Static function executed as the core routine on the new thread. Passed a pointer to a WorkerThread object.
        static void* workerThreadStart(void*);
        void* workerThread();

        ThreadIdentifier m_threadID;
        WorkerRunLoop m_runLoop;
        WorkerLoaderProxy& m_workerLoaderProxy;
        WorkerReportingProxy& m_workerReportingProxy;

        RefPtr<WorkerContext> m_workerContext;
        Mutex m_threadCreationMutex;

        OwnPtr<WorkerThreadStartupData> m_startupData;

#if ENABLE(NOTIFICATIONS)
        NotificationPresenter* m_notificationPresenter;
#endif

        // Track the number of WorkerThread instances for use in layout tests.
        static unsigned m_threadCount;
    };

} // namespace WebCore

#endif // ENABLE(WORKERS)

#endif // WorkerThread_h

