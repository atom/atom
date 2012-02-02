/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies)
 * Portions Copyright (c) 2010 Motorola Mobility, Inc.  All rights reserved.
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

#ifndef RunLoop_h
#define RunLoop_h

#include <wtf/Forward.h>
#include <wtf/Functional.h>
#include <wtf/HashMap.h>
#include <wtf/ThreadSpecific.h>
#include <wtf/Threading.h>
#include <wtf/Vector.h>

#if PLATFORM(GTK)
#include <wtf/gobject/GRefPtr.h>
typedef struct _GSource GSource;
typedef struct _GMainLoop GMainLoop;
typedef struct _GMainContext GMainContext;
typedef int gboolean;
#endif

namespace WebCore {

class RunLoop {
public:
    // Must be called from the main thread (except for the Mac platform, where it
    // can be called from any thread).
    static void initializeMainRunLoop();

    static RunLoop* current();
    static RunLoop* main();

    void dispatch(const Function<void()>&);

    static void run();
    void stop();

#if PLATFORM(MAC)
    void runForDuration(double duration);
#endif
    
    class TimerBase {
        friend class RunLoop;
    public:
        TimerBase(RunLoop*);
        virtual ~TimerBase();

        void startRepeating(double repeatInterval) { start(repeatInterval, true); }
        void startOneShot(double interval) { start(interval, false); }

        void stop();
        bool isActive() const;

        virtual void fired() = 0;

    private:
        void start(double nextFireInterval, bool repeat);

        RunLoop* m_runLoop;

#if PLATFORM(WIN)
        static void timerFired(RunLoop*, uint64_t ID);
        uint64_t m_ID;
        bool m_isRepeating;
#elif PLATFORM(MAC)
        static void timerFired(CFRunLoopTimerRef, void*);
        CFRunLoopTimerRef m_timer;
#elif PLATFORM(QT)
        static void timerFired(RunLoop*, int ID);
        int m_ID;
        bool m_isRepeating;
#elif PLATFORM(GTK)
        static gboolean timerFiredCallback(RunLoop::TimerBase*);
        gboolean isRepeating() const { return m_isRepeating; }
        void clearTimerSource();
        GRefPtr<GSource> m_timerSource;
        gboolean m_isRepeating;
#endif
    };

    template <typename TimerFiredClass>
    class Timer : public TimerBase {
    public:
        typedef void (TimerFiredClass::*TimerFiredFunction)();

        Timer(RunLoop* runLoop, TimerFiredClass* o, TimerFiredFunction f)
            : TimerBase(runLoop)
            , m_object(o)
            , m_function(f)
        {
        }

    private:
        virtual void fired() { (m_object->*m_function)(); }

        TimerFiredClass* m_object;
        TimerFiredFunction m_function;
    };

private:
    friend class WTF::ThreadSpecific<RunLoop>;

    RunLoop();
    ~RunLoop();

    void performWork();
    void wakeUp();

    Mutex m_functionQueueLock;
    Vector<Function<void()> > m_functionQueue;

#if PLATFORM(WIN)
    static bool registerRunLoopMessageWindowClass();
    static LRESULT CALLBACK RunLoopWndProc(HWND, UINT, WPARAM, LPARAM);
    LRESULT wndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
    HWND m_runLoopMessageWindow;

    typedef HashMap<uint64_t, TimerBase*> TimerMap;
    TimerMap m_activeTimers;
#elif PLATFORM(MAC)
    RunLoop(CFRunLoopRef);
    static void performWork(void*);
    CFRunLoopRef m_runLoop;
    CFRunLoopSourceRef m_runLoopSource;
    int m_nestingLevel;
#elif PLATFORM(QT)
    typedef HashMap<int, TimerBase*> TimerMap;
    TimerMap m_activeTimers;
    class TimerObject;
    TimerObject* m_timerObject;
#elif PLATFORM(GTK)
public:
    static gboolean queueWork(RunLoop*);
    GMainLoop* mainLoop();
private:
    GMainContext* m_runLoopContext;
    GMainLoop* m_runLoopMain;
#endif
};

} // namespace WebCore

#endif // RunLoop_h
