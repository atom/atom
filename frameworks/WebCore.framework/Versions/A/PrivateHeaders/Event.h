/*
 * Copyright (C) 2001 Peter Kelly (pmk@post.com)
 * Copyright (C) 2001 Tobias Anton (anton@stud.fbi.fh-darmstadt.de)
 * Copyright (C) 2006 Samuel Weinig (sam.weinig@gmail.com)
 * Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef Event_h
#define Event_h

#include "Clipboard.h"
#include "DOMTimeStamp.h"
#include <wtf/RefCounted.h>
#include <wtf/text/AtomicString.h>

namespace WebCore {

    class EventTarget;
    class EventDispatcher;

    struct EventInit {
        EventInit();
        
        bool bubbles;
        bool cancelable;
    };

    class Event : public RefCounted<Event> {
    public:
        enum PhaseType { 
            CAPTURING_PHASE     = 1, 
            AT_TARGET           = 2,
            BUBBLING_PHASE      = 3 
        };

        enum EventType {
            MOUSEDOWN           = 1,
            MOUSEUP             = 2,
            MOUSEOVER           = 4,
            MOUSEOUT            = 8,
            MOUSEMOVE           = 16,
            MOUSEDRAG           = 32,
            CLICK               = 64,
            DBLCLICK            = 128,
            KEYDOWN             = 256,
            KEYUP               = 512,
            KEYPRESS            = 1024,
            DRAGDROP            = 2048,
            FOCUS               = 4096,
            BLUR                = 8192,
            SELECT              = 16384,
            CHANGE              = 32768
        };

        static PassRefPtr<Event> create()
        {
            return adoptRef(new Event);
        }
        static PassRefPtr<Event> create(const AtomicString& type, bool canBubble, bool cancelable)
        {
            return adoptRef(new Event(type, canBubble, cancelable));
        }

        static PassRefPtr<Event> create(const AtomicString& type, const EventInit& initializer)
        {
            return adoptRef(new Event(type, initializer));
        }

        virtual ~Event();

        void initEvent(const AtomicString& type, bool canBubble, bool cancelable);

        const AtomicString& type() const { return m_type; }
        
        EventTarget* target() const { return m_target.get(); }
        void setTarget(PassRefPtr<EventTarget>);

        EventTarget* currentTarget() const { return m_currentTarget; }
        void setCurrentTarget(EventTarget* currentTarget) { m_currentTarget = currentTarget; }

        unsigned short eventPhase() const { return m_eventPhase; }
        void setEventPhase(unsigned short eventPhase) { m_eventPhase = eventPhase; }

        bool bubbles() const { return m_canBubble; }
        bool cancelable() const { return m_cancelable; }
        DOMTimeStamp timeStamp() const { return m_createTime; }

        void stopPropagation() { m_propagationStopped = true; }
        void stopImmediatePropagation() { m_immediatePropagationStopped = true; }
        
        // IE Extensions
        EventTarget* srcElement() const { return target(); } // MSIE extension - "the object that fired the event"

        bool returnValue() const { return !defaultPrevented(); }
        void setReturnValue(bool returnValue) { setDefaultPrevented(!returnValue); }

        Clipboard* clipboardData() const { return isClipboardEvent() ? clipboard() : 0; }

        virtual const AtomicString& interfaceName() const;
        bool hasInterface(const AtomicString&) const;

        // These events are general classes of events.
        virtual bool isUIEvent() const;
        virtual bool isMouseEvent() const;
        virtual bool isKeyboardEvent() const;

        // Drag events are a subset of mouse events.
        virtual bool isDragEvent() const;

        // These events lack a DOM interface.
        virtual bool isClipboardEvent() const;
        virtual bool isBeforeTextInsertedEvent() const;

        bool propagationStopped() const { return m_propagationStopped || m_immediatePropagationStopped; }
        bool immediatePropagationStopped() const { return m_immediatePropagationStopped; }

        bool defaultPrevented() const { return m_defaultPrevented; }
        void preventDefault() { if (m_cancelable) m_defaultPrevented = true; }
        void setDefaultPrevented(bool defaultPrevented) { m_defaultPrevented = defaultPrevented; }

        bool defaultHandled() const { return m_defaultHandled; }
        void setDefaultHandled() { m_defaultHandled = true; }

        bool cancelBubble() const { return m_cancelBubble; }
        void setCancelBubble(bool cancel) { m_cancelBubble = cancel; }

        Event* underlyingEvent() const { return m_underlyingEvent.get(); }
        void setUnderlyingEvent(PassRefPtr<Event>);

        virtual bool storesResultAsString() const;
        virtual void storeResult(const String&);

        virtual Clipboard* clipboard() const { return 0; }

        bool isBeingDispatched() const { return eventPhase(); }

    protected:
        Event();
        Event(const AtomicString& type, bool canBubble, bool cancelable);
        Event(const AtomicString& type, const EventInit&);

        virtual void receivedTarget();
        bool dispatched() const { return m_target; }

    private:
        AtomicString m_type;
        bool m_canBubble;
        bool m_cancelable;

        bool m_propagationStopped;
        bool m_immediatePropagationStopped;
        bool m_defaultPrevented;
        bool m_defaultHandled;
        bool m_cancelBubble;

        unsigned short m_eventPhase;
        EventTarget* m_currentTarget;
        RefPtr<EventTarget> m_target;
        DOMTimeStamp m_createTime;

        RefPtr<Event> m_underlyingEvent;
    };

} // namespace WebCore

#endif // Event_h
