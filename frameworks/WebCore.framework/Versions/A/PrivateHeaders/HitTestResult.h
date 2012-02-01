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
 *
*/

#ifndef HitTestResult_h
#define HitTestResult_h

#include "FloatRect.h"
#include "LayoutTypes.h"
#include "TextDirection.h"
#include <wtf/Forward.h>
#include <wtf/ListHashSet.h>
#include <wtf/OwnPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class Element;
class Frame;
#if ENABLE(VIDEO)
class HTMLMediaElement;
#endif
class Image;
class KURL;
class Node;
class RenderRegion;
class Scrollbar;

class HitTestResult {
public:
    typedef ListHashSet<RefPtr<Node> > NodeSet;

    HitTestResult();
    HitTestResult(const LayoutPoint&);
    // Pass non-negative padding values to perform a rect-based hit test.
    HitTestResult(const LayoutPoint& centerPoint, unsigned topPadding, unsigned rightPadding, unsigned bottomPadding, unsigned leftPadding);
    HitTestResult(const HitTestResult&);
    ~HitTestResult();
    HitTestResult& operator=(const HitTestResult&);

    Node* innerNode() const { return m_innerNode.get(); }
    Node* innerNonSharedNode() const { return m_innerNonSharedNode.get(); }
    LayoutPoint point() const { return m_point; }
    LayoutPoint localPoint() const { return m_localPoint; }
    Element* URLElement() const { return m_innerURLElement.get(); }
    Scrollbar* scrollbar() const { return m_scrollbar.get(); }
    bool isOverWidget() const { return m_isOverWidget; }

    RenderRegion* region() const { return m_region; }
    void setRegion(RenderRegion* region) { m_region = region; }

    void setToNonShadowAncestor();

    void setInnerNode(Node*);
    void setInnerNonSharedNode(Node*);
    void setPoint(const LayoutPoint& p) { m_point = p; }
    void setLocalPoint(const LayoutPoint& p) { m_localPoint = p; }
    void setURLElement(Element*);
    void setScrollbar(Scrollbar*);
    void setIsOverWidget(bool b) { m_isOverWidget = b; }

    Frame* targetFrame() const;
    bool isSelected() const;
    String spellingToolTip(TextDirection&) const;
    String replacedString() const;
    String title(TextDirection&) const;
    String innerTextIfTruncated(TextDirection&) const;
    String altDisplayString() const;
    String titleDisplayString() const;
    Image* image() const;
    IntRect imageRect() const;
    KURL absoluteImageURL() const;
    KURL absolutePDFURL() const;
    KURL absoluteMediaURL() const;
    KURL absoluteLinkURL() const;
    String textContent() const;
    bool isLiveLink() const;
    bool isContentEditable() const;
    void toggleMediaControlsDisplay() const;
    void toggleMediaLoopPlayback() const;
    void enterFullscreenForVideo() const;
    bool mediaControlsEnabled() const;
    bool mediaLoopEnabled() const;
    bool mediaPlaying() const;
    bool mediaSupportsFullscreen() const;
    void toggleMediaPlayState() const;
    bool mediaHasAudio() const;
    bool mediaIsVideo() const;
    bool mediaMuted() const;
    void toggleMediaMuteState() const;

    // Rect-based hit test related methods.
    bool isRectBasedTest() const { return m_isRectBased; }
    LayoutRect rectForPoint(const LayoutPoint&) const;
    static LayoutRect rectForPoint(const LayoutPoint&, unsigned topPadding, unsigned rightPadding, unsigned bottomPadding, unsigned leftPadding);
    int topPadding() const { return m_topPadding; }
    int rightPadding() const { return m_rightPadding; }
    int bottomPadding() const { return m_bottomPadding; }
    int leftPadding() const { return m_leftPadding; }

    // Returns true if it is rect-based hit test and needs to continue until the rect is fully
    // enclosed by the boundaries of a node.
    bool addNodeToRectBasedTestResult(Node*, const LayoutPoint& pointInContainer, const IntRect& = IntRect());
    bool addNodeToRectBasedTestResult(Node*, const LayoutPoint& pointInContainer, const FloatRect&);
    void append(const HitTestResult&);

    // If m_rectBasedTestResult is 0 then set it to a new NodeSet. Return *m_rectBasedTestResult. Lazy allocation makes
    // sense because the NodeSet is seldom necessary, and it's somewhat expensive to allocate and initialize. This method does
    // the same thing as mutableRectBasedTestResult(), but here the return value is const.
    const NodeSet& rectBasedTestResult() const;

private:
    NodeSet& mutableRectBasedTestResult(); // See above.

#if ENABLE(VIDEO)
    HTMLMediaElement* mediaElement() const;
#endif

    RefPtr<Node> m_innerNode;
    RefPtr<Node> m_innerNonSharedNode;
    LayoutPoint m_point;
    LayoutPoint m_localPoint; // A point in the local coordinate space of m_innerNonSharedNode's renderer. Allows us to efficiently
                              // determine where inside the renderer we hit on subsequent operations.
    RefPtr<Element> m_innerURLElement;
    RefPtr<Scrollbar> m_scrollbar;
    bool m_isOverWidget; // Returns true if we are over a widget (and not in the border/padding area of a RenderWidget for example).
    bool m_isRectBased;
    int m_topPadding;
    int m_rightPadding;
    int m_bottomPadding;
    int m_leftPadding;
    
    RenderRegion* m_region; // The region we're inside.

    mutable OwnPtr<NodeSet> m_rectBasedTestResult;
};

// Formula:
// x = p.x() - rightPadding
// y = p.y() - topPadding
// width = leftPadding + rightPadding + 1
// height = topPadding + bottomPadding + 1
inline LayoutRect HitTestResult::rectForPoint(const LayoutPoint& point) const
{
    return rectForPoint(point, m_topPadding, m_rightPadding, m_bottomPadding, m_leftPadding);
}

String displayString(const String&, const Node*);

} // namespace WebCore

#endif // HitTestResult_h
