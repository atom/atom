/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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
 */

#ifndef Timer_h
#define Timer_h

#include <wtf/Noncopyable.h>
#include <wtf/Threading.h>

namespace WebCore {

// Time intervals are all in seconds.

class TimerHeapElement;

class TimerBase {
    WTF_MAKE_NONCOPYABLE(TimerBase); WTF_MAKE_FAST_ALLOCATED;
public:
    TimerBase();
    virtual ~TimerBase();

    void start(double nextFireInterval, double repeatInterval);

    void startRepeating(double repeatInterval) { start(repeatInterval, repeatInterval); }
    void startOneShot(double interval) { start(interval, 0); }

    void stop();
    bool isActive() const;

    double nextFireInterval() const;
    double repeatInterval() const { return m_repeatInterval; }

    void augmentFireInterval(double delta) { setNextFireTime(m_nextFireTime + delta); }
    void augmentRepeatInterval(double delta) { augmentFireInterval(delta); m_repeatInterval += delta; }

    static void fireTimersInNestedEventLoop();

private:
    virtual void fired() = 0;

    void checkConsistency() const;
    void checkHeapIndex() const;

    void setNextFireTime(double);

    bool inHeap() const { return m_heapIndex != -1; }

    void heapDecreaseKey();
    void heapDelete();
    void heapDeleteMin();
    void heapIncreaseKey();
    void heapInsert();
    void heapPop();
    void heapPopMin();

    double m_nextFireTime; // 0 if inactive
    double m_repeatInterval; // 0 if not repeating
    int m_heapIndex; // -1 if not in heap
    unsigned m_heapInsertionOrder; // Used to keep order among equal-fire-time timers

#ifndef NDEBUG
    ThreadIdentifier m_thread;
#endif

    friend class ThreadTimers;
    friend class TimerHeapLessThanFunction;
    friend class TimerHeapReference;
};

template <typename TimerFiredClass> class Timer : public TimerBase {
public:
    typedef void (TimerFiredClass::*TimerFiredFunction)(Timer*);

    Timer(TimerFiredClass* o, TimerFiredFunction f)
        : m_object(o), m_function(f) { }

private:
    virtual void fired() { (m_object->*m_function)(this); }

    TimerFiredClass* m_object;
    TimerFiredFunction m_function;
};

inline bool TimerBase::isActive() const
{
    ASSERT(m_thread == currentThread());
    return m_nextFireTime;
}

}

#endif
