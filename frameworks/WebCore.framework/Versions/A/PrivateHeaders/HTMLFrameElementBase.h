/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Simon Hausmann <hausmann@kde.org>
 * Copyright (C) 2004, 2006, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef HTMLFrameElementBase_h
#define HTMLFrameElementBase_h

#include "HTMLFrameOwnerElement.h"
#include "ScrollTypes.h"

namespace WebCore {

class HTMLFrameElementBase : public HTMLFrameOwnerElement {
public:
    KURL location() const;
    void setLocation(const String&);

    virtual ScrollbarMode scrollingMode() const { return m_scrolling; }
    
    int marginWidth() const { return m_marginWidth; }
    int marginHeight() const { return m_marginHeight; }

    int width();
    int height();

    bool canRemainAliveOnRemovalFromTree();
    void setRemainsAliveOnRemovalFromTree(bool);
#if ENABLE(FULLSCREEN_API)
    virtual bool allowFullScreen() const;
#endif

    virtual bool canContainRangeEndPoint() const { return false; }

protected:
    HTMLFrameElementBase(const QualifiedName&, Document*);

    bool isURLAllowed() const;

    virtual void parseMappedAttribute(Attribute*);
    virtual void insertedIntoDocument();
    virtual void attach();

private:
    virtual bool supportsFocus() const;
    virtual void setFocus(bool);
    
    virtual bool isURLAttribute(Attribute*) const;
    virtual bool isFrameElementBase() const { return true; }

    virtual void willRemove();
    void checkInDocumentTimerFired(Timer<HTMLFrameElementBase>*);
    void updateOnReparenting();

    bool viewSourceMode() const { return m_viewSource; }

    void setNameAndOpenURL();
    void openURL(bool lockHistory = true, bool lockBackForwardList = true);

    AtomicString m_URL;
    AtomicString m_frameName;

    ScrollbarMode m_scrolling;

    int m_marginWidth;
    int m_marginHeight;

    // This is a performance optimization some call "magic iframe" which avoids
    // tearing down the frame hierarchy when a web page calls adoptNode on a
    // frame owning element but does not immediately insert it into the new
    // document before JavaScript yields to WebCore.  If the element is not yet
    // in a document by the time this timer fires, the frame hierarchy teardown
    // will continue.  This can also be seen as implementation of:
    // "Removing an iframe from a Document does not cause its browsing context
    // to be discarded. Indeed, an iframe's browsing context can survive its
    // original parent Document if its iframe is moved to another Document."
    // From HTML5: http://www.whatwg.org/specs/web-apps/current-work/multipage/the-iframe-element.html#the-iframe-element
    Timer<HTMLFrameElementBase> m_checkInDocumentTimer;

    bool m_viewSource;
    bool m_remainsAliveOnRemovalFromTree;
};

} // namespace WebCore

#endif // HTMLFrameElementBase_h
