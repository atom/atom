/*
 * Copyright (C) 2010 Apple Inc. All Rights Reserved.
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

#ifndef StackBounds_h
#define StackBounds_h

namespace WTF {

class StackBounds {
    // recursionCheck() / recursionLimit() tests (by default)
    // that we are at least this far from the end of the stack.
    const static size_t s_defaultAvailabilityDelta = 4096;

public:
    StackBounds()
        : m_origin(0)
        , m_bound(0)
    {
    }

    static StackBounds currentThreadStackBounds()
    {
        StackBounds bounds;
        bounds.initialize();
        bounds.checkConsistency();
        return bounds;
    }

    void* origin() const
    {
        ASSERT(m_origin);
        return m_origin;
    }

    void* current() const
    {
        checkConsistency();
        void* currentPosition = &currentPosition;
        return currentPosition;
    }

    void* recursionLimit(size_t minAvailableDelta = s_defaultAvailabilityDelta) const
    {
        checkConsistency();
        return isGrowingDownward()
            ? static_cast<char*>(m_bound) + minAvailableDelta
            : static_cast<char*>(m_bound) - minAvailableDelta;
    }

    bool recursionCheck(size_t minAvailableDelta = s_defaultAvailabilityDelta) const
    {
        checkConsistency();
        return isGrowingDownward()
            ? current() >= recursionLimit(minAvailableDelta)
            : current() <= recursionLimit(minAvailableDelta);
    }

private:
    void initialize();


    bool isGrowingDownward() const
    {
        ASSERT(m_origin && m_bound);
#if OS(WINCE)
        return m_origin > m_bound;
#else
        return true;
#endif
    }

    void checkConsistency() const
    {
#if !ASSERT_DISABLED
        void* currentPosition = &currentPosition;
        ASSERT(m_origin != m_bound);
        ASSERT(isGrowingDownward()
            ? (currentPosition < m_origin && currentPosition > m_bound)
            : (currentPosition > m_origin && currentPosition < m_bound));
#endif
    }

    void* m_origin;
    void* m_bound;
};

} // namespace WTF

using WTF::StackBounds;

#endif
