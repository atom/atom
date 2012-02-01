/*
 * Copyright (C) 2006 Apple Computer, Inc.
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
 */

#ifndef FrameTree_h
#define FrameTree_h

#include <wtf/text/AtomicString.h>

namespace WebCore {

    class Frame;

    class FrameTree {
        WTF_MAKE_NONCOPYABLE(FrameTree);
    public:
        FrameTree(Frame* thisFrame, Frame* parentFrame) 
            : m_thisFrame(thisFrame)
            , m_parent(parentFrame)
            , m_previousSibling(0)
            , m_lastChild(0)
            , m_childCount(0)
        {
        }
        ~FrameTree();

        const AtomicString& name() const { return m_name; }
        const AtomicString& uniqueName() const { return m_uniqueName; }
        void setName(const AtomicString&);
        void clearName();
        Frame* parent(bool checkForDisconnectedFrame = false) const;
        void setParent(Frame* parent) { m_parent = parent; }
        
        Frame* nextSibling() const { return m_nextSibling.get(); }
        Frame* previousSibling() const { return m_previousSibling; }
        Frame* firstChild() const { return m_firstChild.get(); }
        Frame* lastChild() const { return m_lastChild; }
        unsigned childCount() const { return m_childCount; }

        bool isDescendantOf(const Frame* ancestor) const;
        Frame* traverseNext(const Frame* stayWithin = 0) const;
        Frame* traverseNextWithWrap(bool) const;
        Frame* traversePreviousWithWrap(bool) const;
        
        void appendChild(PassRefPtr<Frame>);
        bool transferChild(PassRefPtr<Frame>);
        void detachFromParent() { m_parent = 0; }
        void removeChild(Frame*);

        Frame* child(unsigned index) const;
        Frame* child(const AtomicString& name) const;
        Frame* find(const AtomicString& name) const;

        AtomicString uniqueChildName(const AtomicString& requestedName) const;

        Frame* top(bool checkForDisconnectedFrame = false) const;

    private:
        Frame* deepLastChild() const;
        void actuallyAppendChild(PassRefPtr<Frame>);

        Frame* m_thisFrame;

        Frame* m_parent;
        AtomicString m_name; // The actual frame name (may be empty).
        AtomicString m_uniqueName;

        // FIXME: use ListRefPtr?
        RefPtr<Frame> m_nextSibling;
        Frame* m_previousSibling;
        RefPtr<Frame> m_firstChild;
        Frame* m_lastChild;
        unsigned m_childCount;
    };

} // namespace WebCore

#ifndef NDEBUG
// Outside the WebCore namespace for ease of invocation from gdb.
void showFrameTree(const WebCore::Frame*);
#endif

#endif // FrameTree_h
