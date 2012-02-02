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

#ifndef UIEvent_h
#define UIEvent_h

#include "DOMWindow.h"
#include "Event.h"
#include "EventDispatchMediator.h"

namespace WebCore {

    typedef DOMWindow AbstractView;

    class UIEvent : public Event {
    public:
        static PassRefPtr<UIEvent> create()
        {
            return adoptRef(new UIEvent);
        }
        static PassRefPtr<UIEvent> create(const AtomicString& type, bool canBubble, bool cancelable, PassRefPtr<AbstractView> view, int detail)
        {
            return adoptRef(new UIEvent(type, canBubble, cancelable, view, detail));
        }
        virtual ~UIEvent();

        void initUIEvent(const AtomicString& type, bool canBubble, bool cancelable, PassRefPtr<AbstractView>, int detail);

        AbstractView* view() const { return m_view.get(); }
        int detail() const { return m_detail; }

        virtual const AtomicString& interfaceName() const;
        virtual bool isUIEvent() const;

        virtual int keyCode() const;
        virtual int charCode() const;

        virtual int layerX();
        virtual int layerY();

        virtual int pageX() const;
        virtual int pageY() const;

        virtual int which() const;

    protected:
        UIEvent();
        UIEvent(const AtomicString& type, bool canBubble, bool cancelable, PassRefPtr<AbstractView>, int detail);

        // layerX and layerY are deprecated. This reports a message to the console until we remove them.
        void warnDeprecatedLayerXYUsage();

    private:
        RefPtr<AbstractView> m_view;
        int m_detail;
    };

    class FocusInEventDispatchMediator : public EventDispatchMediator {
    public:
        static PassRefPtr<FocusInEventDispatchMediator> create(PassRefPtr<Event>, PassRefPtr<Node> oldFocusedNode);
    private:
        explicit FocusInEventDispatchMediator(PassRefPtr<Event>, PassRefPtr<Node> oldFocusedNode);
        virtual bool dispatchEvent(EventDispatcher*) const;
        RefPtr<Node> m_oldFocusedNode;
    };

    class FocusOutEventDispatchMediator : public EventDispatchMediator {
    public:
        static PassRefPtr<FocusOutEventDispatchMediator> create(PassRefPtr<Event>, PassRefPtr<Node> newFocusedNode);
    private:
        explicit FocusOutEventDispatchMediator(PassRefPtr<Event>, PassRefPtr<Node> newFocusedNode);
        virtual bool dispatchEvent(EventDispatcher*) const;
        RefPtr<Node> m_newFocusedNode;
    };

} // namespace WebCore

#endif // UIEvent_h
