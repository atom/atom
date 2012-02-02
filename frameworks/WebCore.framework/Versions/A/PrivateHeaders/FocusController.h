/*
 * Copyright (C) 2006, 2007 Apple Inc. All rights reserved.
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

#ifndef FocusController_h
#define FocusController_h

#include "FocusDirection.h"
#include "LayoutTypes.h"
#include <wtf/Forward.h>
#include <wtf/Noncopyable.h>
#include <wtf/RefPtr.h>

namespace WebCore {

struct FocusCandidate;
class Element;
class Frame;
class IntRect;
class KeyboardEvent;
class Node;
class Page;
class TreeScope;

class FocusController {
    WTF_MAKE_NONCOPYABLE(FocusController); WTF_MAKE_FAST_ALLOCATED;
public:
    static PassOwnPtr<FocusController> create(Page*);

    void setFocusedFrame(PassRefPtr<Frame>);
    Frame* focusedFrame() const { return m_focusedFrame.get(); }
    Frame* focusedOrMainFrame() const;

    bool setInitialFocus(FocusDirection, KeyboardEvent*);
    bool advanceFocus(FocusDirection, KeyboardEvent*, bool initialFocus = false);
        
    bool setFocusedNode(Node*, PassRefPtr<Frame>);

    void setActive(bool);
    bool isActive() const { return m_isActive; }

    void setFocused(bool);
    bool isFocused() const { return m_isFocused; }

    bool transferFocusToElementInShadowRoot(Element* shadowHost, bool restorePreviousSelection);

private:
    FocusController(Page*);

    bool advanceFocusDirectionally(FocusDirection, KeyboardEvent*);
    bool advanceFocusInDocumentOrder(FocusDirection, KeyboardEvent*, bool initialFocus);

    Node* findFocusableNodeAcrossTreeScope(FocusDirection, TreeScope* startScope, Node* start, KeyboardEvent*);
    Node* findFocusableNodeDecendingDownIntoFrameDocumentOrShadowRoot(FocusDirection, Node*, KeyboardEvent*);

    // Searches through the given tree scope, starting from start node, for the next/previous selectable element that comes after/before start node.
    // The order followed is as specified in section 17.11.1 of the HTML4 spec, which is elements with tab indexes
    // first (from lowest to highest), and then elements without tab indexes (in document order).
    //
    // @param start The node from which to start searching. The node after this will be focused. May be null.
    //
    // @return The focus node that comes after/before start node.
    //
    // See http://www.w3.org/TR/html4/interact/forms.html#h-17.11.1
    inline Node* findFocusableNode(FocusDirection, TreeScope*, Node* start, KeyboardEvent*);

    Node* nextFocusableNode(TreeScope*, Node* start, KeyboardEvent*);
    Node* previousFocusableNode(TreeScope*, Node* start, KeyboardEvent*);

    bool advanceFocusDirectionallyInContainer(Node* container, const LayoutRect& startingRect, FocusDirection, KeyboardEvent*);
    void findFocusCandidateInContainer(Node* container, const LayoutRect& startingRect, FocusDirection, KeyboardEvent*, FocusCandidate& closest);

    Page* m_page;
    RefPtr<Frame> m_focusedFrame;
    bool m_isActive;
    bool m_isFocused;
    bool m_isChangingFocusedFrame;

};

} // namespace WebCore
    
#endif // FocusController_h
