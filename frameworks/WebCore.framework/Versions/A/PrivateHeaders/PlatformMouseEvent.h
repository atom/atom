/*
 * Copyright (C) 2004, 2005, 2006, 2009 Apple Inc. All rights reserved.
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

#ifndef PlatformMouseEvent_h
#define PlatformMouseEvent_h

#include "IntPoint.h"
#include "PlatformEvent.h"

#if PLATFORM(GTK)
typedef struct _GdkEventButton GdkEventButton;
typedef struct _GdkEventMotion GdkEventMotion;
#endif

#if PLATFORM(EFL)
typedef struct _Evas_Event_Mouse_Down Evas_Event_Mouse_Down;
typedef struct _Evas_Event_Mouse_Up Evas_Event_Mouse_Up;
typedef struct _Evas_Event_Mouse_Move Evas_Event_Mouse_Move;
#endif

#if PLATFORM(QT)
QT_BEGIN_NAMESPACE
class QInputEvent;
class QGraphicsSceneMouseEvent;
QT_END_NAMESPACE
#endif

#if PLATFORM(WIN)
typedef struct HWND__* HWND;
typedef unsigned UINT;
typedef unsigned WPARAM;
typedef long LPARAM;
#endif

#if PLATFORM(WX)
class wxMouseEvent;
#endif

namespace WebCore {
    
    // These button numbers match the ones used in the DOM API, 0 through 2, except for NoButton which isn't specified.
    enum MouseButton { NoButton = -1, LeftButton, MiddleButton, RightButton };
    
    class PlatformMouseEvent : public PlatformEvent {
    public:
        PlatformMouseEvent()
            : PlatformEvent(PlatformEvent::MouseMoved)
            , m_button(NoButton)
            , m_clickCount(0)
            , m_modifierFlags(0)
#if PLATFORM(MAC)
            , m_eventNumber(0)
#elif PLATFORM(WIN)
            , m_didActivateWebView(false)
#endif
        {
        }

        PlatformMouseEvent(const IntPoint& position, const IntPoint& globalPosition, MouseButton button, PlatformEvent::Type type,
                           int clickCount, bool shiftKey, bool ctrlKey, bool altKey, bool metaKey, double timestamp)
            : PlatformEvent(type, shiftKey, ctrlKey, altKey, metaKey, timestamp)
            , m_position(position)
            , m_globalPosition(globalPosition)
            , m_button(button)
            , m_clickCount(clickCount)
            , m_modifierFlags(0)
#if PLATFORM(MAC)
            , m_eventNumber(0)
#elif PLATFORM(WIN)
            , m_didActivateWebView(false)
#endif
        {
        }

        const IntPoint& position() const { return m_position; }
        const IntPoint& globalPosition() const { return m_globalPosition; }
#if ENABLE(POINTER_LOCK)
        const IntPoint& movementDelta() const { return m_movementDelta; }
#endif

        MouseButton button() const { return m_button; }
        int clickCount() const { return m_clickCount; }
        unsigned modifierFlags() const { return m_modifierFlags; }
        

#if PLATFORM(GTK) 
        PlatformMouseEvent(GdkEventButton*);
        PlatformMouseEvent(GdkEventMotion*);
        void setClickCount(int count) { m_clickCount = count; }
#endif

#if PLATFORM(EFL)
        void setClickCount(unsigned int);
        PlatformMouseEvent(const Evas_Event_Mouse_Down*, IntPoint);
        PlatformMouseEvent(const Evas_Event_Mouse_Up*, IntPoint);
        PlatformMouseEvent(const Evas_Event_Mouse_Move*, IntPoint);
#endif

#if PLATFORM(MAC)
        int eventNumber() const { return m_eventNumber; }
#endif

#if PLATFORM(QT)
        PlatformMouseEvent(QInputEvent*, int clickCount);
        PlatformMouseEvent(QGraphicsSceneMouseEvent*, int clickCount);
#endif

#if PLATFORM(WIN)
        PlatformMouseEvent(HWND, UINT, WPARAM, LPARAM, bool didActivateWebView = false);
        void setClickCount(int count) { m_clickCount = count; }
        bool didActivateWebView() const { return m_didActivateWebView; }
#endif

#if PLATFORM(WX)
        PlatformMouseEvent(const wxMouseEvent&, const wxPoint& globalPoint, int clickCount);
#endif

    protected:
        IntPoint m_position;
        IntPoint m_globalPosition;
#if ENABLE(POINTER_LOCK)
        IntPoint m_movementDelta;
#endif
        MouseButton m_button;
        int m_clickCount;
        unsigned m_modifierFlags;

#if PLATFORM(MAC)
        int m_eventNumber;
#elif PLATFORM(WIN)
        bool m_didActivateWebView;
#endif
    };

} // namespace WebCore

#endif // PlatformMouseEvent_h
