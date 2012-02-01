/*
 * Copyright (C) 2011 Apple Inc.  All rights reserved.
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

#ifndef PlatformGestureEvent_h
#define PlatformGestureEvent_h

#if ENABLE(GESTURE_EVENTS)

#include "IntPoint.h"
#include "PlatformEvent.h"

namespace WebCore {

class PlatformGestureEvent : public PlatformEvent {
public:
    PlatformGestureEvent()
        : PlatformEvent(PlatformEvent::GestureScrollBegin)
        , m_deltaX(0)
        , m_deltaY(0)
    {
    }

    PlatformGestureEvent(Type type, const IntPoint& position, const IntPoint& globalPosition, double timestamp, float deltaX, float deltaY, bool shiftKey, bool ctrlKey, bool altKey, bool metaKey)
        : PlatformEvent(type, shiftKey, ctrlKey, altKey, metaKey, timestamp)
        , m_position(position)
        , m_globalPosition(globalPosition)
        , m_deltaX(deltaX)
        , m_deltaY(deltaY)
    {
    }

    const IntPoint& position() const { return m_position; } // PlatformWindow coordinates.
    const IntPoint& globalPosition() const { return m_globalPosition; } // Screen coordinates.

    float deltaX() const { return m_deltaX; }
    float deltaY() const { return m_deltaY; }
    
protected:
    IntPoint m_position;
    IntPoint m_globalPosition;
    float m_deltaX;
    float m_deltaY;
};

} // namespace WebCore

#endif // ENABLE(GESTURE_EVENTS)

#endif // PlatformGestureEvent_h
