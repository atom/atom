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

#ifndef ParallelJobsOpenMP_h
#define ParallelJobsOpenMP_h

#if ENABLE(THREADING_OPENMP)

#include <omp.h>

namespace WTF {

class ParallelEnvironment {
    WTF_MAKE_NONCOPYABLE(ParallelEnvironment);
public:
    typedef void (*ThreadFunction)(void*);

    ParallelEnvironment(ThreadFunction threadFunction, size_t sizeOfParameter, int requestedJobNumber) :
        m_threadFunction(threadFunction),
        m_sizeOfParameter(sizeOfParameter)
    {
        int maxNumberOfThreads = omp_get_max_threads();

        if (!requestedJobNumber || requestedJobNumber > maxNumberOfThreads)
            requestedJobNumber = maxNumberOfThreads;

        ASSERT(requestedJobNumber > 0);

        m_numberOfJobs = requestedJobNumber;

    }

    int numberOfJobs()
    {
        return m_numberOfJobs;
    }

    void execute(unsigned char* parameters)
    {
        omp_set_num_threads(m_numberOfJobs);

#pragma omp parallel for
        for (int i = 0; i < m_numberOfJobs; ++i)
            (*m_threadFunction)(parameters + i * m_sizeOfParameter);
    }

private:
    ThreadFunction m_threadFunction;
    size_t m_sizeOfParameter;
    int m_numberOfJobs;
};

} // namespace WTF

#endif // ENABLE(THREADING_OPENMP)

#endif // ParallelJobsOpenMP_h
