/*
 * Copyright (C) 2011 University of Szeged
 * Copyright (C) 2011 Gabor Loki <loki@webkit.org>
 * All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY UNIVERSITY OF SZEGED ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL UNIVERSITY OF SZEGED OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ParallelJobsGeneric_h
#define ParallelJobsGeneric_h

#if ENABLE(THREADING_GENERIC)

#include <wtf/RefCounted.h>
#include <wtf/Threading.h>

namespace WTF {

class ParallelEnvironment {
    WTF_MAKE_FAST_ALLOCATED;
public:
    typedef void (*ThreadFunction)(void*);

    ParallelEnvironment(ThreadFunction, size_t sizeOfParameter, int requestedJobNumber);

    int numberOfJobs()
    {
        return m_numberOfJobs;
    }

    void execute(void* parameters);

    class ThreadPrivate : public RefCounted<ThreadPrivate> {
    public:
        ThreadPrivate()
            : m_threadID(0)
            , m_running(false)
            , m_parent(0)
        {
        }

        bool tryLockFor(ParallelEnvironment*);

        void execute(ThreadFunction, void*);

        void waitForFinish();

        static PassRefPtr<ThreadPrivate> create()
        {
            return adoptRef(new ThreadPrivate());
        }

        static void* workerThread(void*);

    private:
        ThreadIdentifier m_threadID;
        bool m_running;
        ParallelEnvironment* m_parent;

        mutable Mutex m_mutex;
        ThreadCondition m_threadCondition;

        ThreadFunction m_threadFunction;
        void* m_parameters;
    };

private:
    ThreadFunction m_threadFunction;
    size_t m_sizeOfParameter;
    int m_numberOfJobs;

    Vector< RefPtr<ThreadPrivate> > m_threads;
    static Vector< RefPtr<ThreadPrivate> >* s_threadPool;
};

} // namespace WTF

#endif // ENABLE(THREADING_GENERIC)


#endif // ParallelJobsGeneric_h
