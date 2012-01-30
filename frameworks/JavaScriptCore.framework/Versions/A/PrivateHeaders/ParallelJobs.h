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

#ifndef ParallelJobs_h
#define ParallelJobs_h

#include "Assertions.h"
#include "Noncopyable.h"
#include "RefPtr.h"
#include <wtf/Vector.h>

// Usage:
//
//     // Initialize parallel jobs
//     ParallelJobs<TypeOfParameter> parallelJobs(&worker [, requestedNumberOfJobs]);
//
//     // Fill the parameter array
//     for(i = 0; i < parallelJobs.numberOfJobs(); ++i) {
//       TypeOfParameter& params = parallelJobs.parameter(i);
//       params.attr1 = localVars ...
//       ...
//     }
//
//     // Execute parallel jobs
//     parallelJobs.execute();
//

#if ENABLE(THREADING_GENERIC)
#include "ParallelJobsGeneric.h"

#elif ENABLE(THREADING_OPENMP)
#include "ParallelJobsOpenMP.h"

#elif ENABLE(THREADING_LIBDISPATCH)
#include "ParallelJobsLibdispatch.h"

#else
#error "No parallel processing API for ParallelJobs"

#endif

namespace WTF {

template<typename Type>
class ParallelJobs {
    WTF_MAKE_FAST_ALLOCATED;
public:
    typedef void (*WorkerFunction)(Type*);

    ParallelJobs(WorkerFunction func, int requestedJobNumber) :
        m_parallelEnvironment(reinterpret_cast<ParallelEnvironment::ThreadFunction>(func), sizeof(Type), requestedJobNumber)
    {
        m_parameters.grow(m_parallelEnvironment.numberOfJobs());
        ASSERT(numberOfJobs() == m_parameters.size());
    }

    size_t numberOfJobs()
    {
        return m_parameters.size();
    }

    Type& parameter(size_t i)
    {
        return m_parameters[i];
    }

    void execute()
    {
        m_parallelEnvironment.execute(reinterpret_cast<unsigned char*>(m_parameters.data()));
    }

private:
    ParallelEnvironment m_parallelEnvironment;
    Vector<Type> m_parameters;
};

} // namespace WTF

using WTF::ParallelJobs;

#endif // ParallelJobs_h
