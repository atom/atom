/*
 * Copyright (C) 2001 Peter Kelly (pmk@post.com)
 * Copyright (C) 2001 Tobias Anton (anton@stud.fbi.fh-darmstadt.de)
 * Copyright (C) 2006 Samuel Weinig (sam.weinig@gmail.com)
 * Copyright (C) 2003, 2004, 2005, 2006, 2008 Apple Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef MouseEvent_h
#define MouseEvent_h

#include "Clipboard.h"
#include "EventDispatchMediator.h"
#include "MouseRelatedEvent.h"

namespace WebCore {

class EventDispatcher;
class PlatformMouseEvent;

    // Introduced in DOM Level 2
    class MouseEvent : public MouseRelatedEvent {
    public:
        static PassRefPtr<MouseEvent> create()
        {
            return adoptRef(new MouseEvent);
        }
        static PassRefPtr<MouseEvent> create(const AtomicString& type, bool canBubble, bool cancelable, PassRefPtr<AbstractView> view,
            int detail, int screenX, int screenY, int pageX, int pageY,
#if ENABLE(POINTER_LOCK)
            int movementX, int movementY,
#endif
            bool ctrlKey, bool altKey, bool shiftKey, bool metaKey, unsigned short button,
            PassRefPtr<EventTarget> relatedTarget, PassRefPtr<Clipboard> clipboard = 0, bool isSimulated = false)
        {
            return adoptRef(new MouseEvent(type, canBubble, cancelable, view, detail, screenX, screenY, pageX, pageY,
#if ENABLE(POINTER_LOCK)
                movementX, movementY,
#endif
                ctrlKey, altKey, shiftKey, metaKey, button, relatedTarget, clipboard, isSimulated));
        }
        static PassRefPtr<MouseEvent> create(const AtomicString& eventType, PassRefPtr<AbstractView>, const PlatformMouseEvent&, int detail, PassRefPtr<Node> relatedTarget);

        virtual ~MouseEvent();

        void initMouseEvent(const AtomicString& type, bool canBubble, bool cancelable, PassRefPtr<AbstractView>,
                            int detail, int screenX, int screenY, int clientX, int clientY,
                            bool ctrlKey, bool altKey, bool shiftKey, bool metaKey,
                            unsigned short button, PassRefPtr<EventTarget> relatedTarget);

        // WinIE uses 1,4,2 for left/middle/right but not for click (just for mousedown/up, maybe others),
        // but we will match the standard DOM.
        unsigned short button() const { return m_button; }
        bool buttonDown() const { return m_buttonDown; }
        EventTarget* relatedTarget() const { return m_relatedTarget.get(); }
        void setRelatedTarget(PassRefPtr<EventTarget> relatedTarget) { m_relatedTarget = relatedTarget; }

        Clipboard* clipboard() const { return m_clipboard.get(); }

        Node* toElement() const;
        Node* fromElement() const;

        Clipboard* dataTransfer() const { return isDragEvent() ? m_clipboard.get() : 0; }

        virtual const AtomicString& interfaceName() const;

        virtual bool isMouseEvent() const;
        virtual bool isDragEvent() const;
        virtual int which() const;

    protected:
        MouseEvent(const AtomicString& type, bool canBubble, bool cancelable, PassRefPtr<AbstractView>,
                   int detail, int screenX, int screenY, int pageX, int pageY,
#if ENABLE(POINTER_LOCK)
                   int movementX, int movementY,
#endif
                   bool ctrlKey, bool altKey, bool shiftKey, bool metaKey, unsigned short button,
                   PassRefPtr<EventTarget> relatedTarget, PassRefPtr<Clipboard> clipboard, bool isSimulated);

    private:
        MouseEvent();

        unsigned short m_button;
        bool m_buttonDown;
        RefPtr<EventTarget> m_relatedTarget;
        RefPtr<Clipboard> m_clipboard;
    };

class SimulatedMouseEvent : public MouseEvent {
public:
    static PassRefPtr<SimulatedMouseEvent> create(const AtomicString& eventType, PassRefPtr<AbstractView>, PassRefPtr<Event> underlyingEvent);
    virtual ~SimulatedMouseEvent();

private:
    SimulatedMouseEvent(const AtomicString& eventType, PassRefPtr<AbstractView>, PassRefPtr<Event> underlyingEvent);
};

class MouseEventDispatchMediator : public EventDispatchMediator {
public:
    static PassRefPtr<MouseEventDispatchMediator> create(PassRefPtr<MouseEvent>);

private:
    explicit MouseEventDispatchMediator(PassRefPtr<MouseEvent>);
    MouseEvent* event() const;

    virtual bool dispatchEvent(EventDispatcher*) const;
};

} // namespace WebCore

#endif // MouseEvent_h
