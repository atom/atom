/*
 * Copyright (C) 2008, 2011 Apple Inc. All Rights Reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef ScrollableArea_h
#define ScrollableArea_h

#include "Scrollbar.h"
#include <wtf/Vector.h>

namespace WebCore {

class FloatPoint;
class GraphicsContext;
class PlatformGestureEvent;
class PlatformWheelEvent;
class ScrollAnimator;
#if USE(ACCELERATED_COMPOSITING)
class GraphicsLayer;
#endif

class ScrollableArea {
public:
    enum ZoomAnimationState { ZoomAnimationContinuing, ZoomAnimationFinishing };

    bool scroll(ScrollDirection, ScrollGranularity, float multiplier = 1);
    void scrollToOffsetWithoutAnimation(const FloatPoint&);
    void scrollToOffsetWithoutAnimation(ScrollbarOrientation, float offset);
    void scrollToXOffsetWithoutAnimation(float x);
    void scrollToYOffsetWithoutAnimation(float x);

    virtual void zoomAnimatorTransformChanged(float, float, float, ZoomAnimationState);

    bool handleWheelEvent(const PlatformWheelEvent&);
#if ENABLE(GESTURE_EVENTS)
    void handleGestureEvent(const PlatformGestureEvent&);
#endif

    // Functions for controlling if you can scroll past the end of the document.
    bool constrainsScrollingToContentEdge() const { return m_constrainsScrollingToContentEdge; }
    void setConstrainsScrollingToContentEdge(bool constrainsScrollingToContentEdge) { m_constrainsScrollingToContentEdge = constrainsScrollingToContentEdge; }

    void setVerticalScrollElasticity(ScrollElasticity scrollElasticity) { m_verticalScrollElasticity = scrollElasticity; }
    ScrollElasticity verticalScrollElasticity() const { return static_cast<ScrollElasticity>(m_verticalScrollElasticity); }

    void setHorizontalScrollElasticity(ScrollElasticity scrollElasticity) { m_horizontalScrollElasticity = scrollElasticity; }
    ScrollElasticity horizontalScrollElasticity() const { return static_cast<ScrollElasticity>(m_horizontalScrollElasticity); }

    bool inLiveResize() const { return m_inLiveResize; }
    void willStartLiveResize();
    void willEndLiveResize();

    void contentAreaWillPaint() const;
    void mouseEnteredContentArea() const;
    void mouseExitedContentArea() const;
    void mouseMovedInContentArea() const;
    void mouseEnteredScrollbar(Scrollbar*) const;
    void mouseExitedScrollbar(Scrollbar*) const;
    void contentAreaDidShow() const;
    void contentAreaDidHide() const;

    void didAddVerticalScrollbar(Scrollbar*);
    void willRemoveVerticalScrollbar(Scrollbar*);
    virtual void didAddHorizontalScrollbar(Scrollbar*);
    virtual void willRemoveHorizontalScrollbar(Scrollbar*);

    virtual void contentsResized();

    bool hasOverlayScrollbars() const;
    virtual void setScrollbarOverlayStyle(ScrollbarOverlayStyle);
    ScrollbarOverlayStyle scrollbarOverlayStyle() const { return static_cast<ScrollbarOverlayStyle>(m_scrollbarOverlayStyle); }

    ScrollAnimator* scrollAnimator() const;
    const IntPoint& scrollOrigin() const { return m_scrollOrigin; }
    bool scrollOriginChanged() const { return m_scrollOriginChanged; }

    virtual bool isActive() const = 0;
    virtual int scrollSize(ScrollbarOrientation) const = 0;
    virtual int scrollPosition(Scrollbar*) const = 0;
    void invalidateScrollbar(Scrollbar*, const IntRect&);
    virtual bool isScrollCornerVisible() const = 0;
    virtual IntRect scrollCornerRect() const = 0;
    void invalidateScrollCorner(const IntRect&);
    virtual void getTickmarks(Vector<IntRect>&) const { }

    // This function should be overriden by subclasses to perform the actual
    // scroll of the content.
    virtual void setScrollOffset(const IntPoint&) = 0;

    // Convert points and rects between the scrollbar and its containing view.
    // The client needs to implement these in order to be aware of layout effects
    // like CSS transforms.
    virtual IntRect convertFromScrollbarToContainingView(const Scrollbar* scrollbar, const IntRect& scrollbarRect) const
    {
        return scrollbar->Widget::convertToContainingView(scrollbarRect);
    }
    virtual IntRect convertFromContainingViewToScrollbar(const Scrollbar* scrollbar, const IntRect& parentRect) const
    {
        return scrollbar->Widget::convertFromContainingView(parentRect);
    }
    virtual IntPoint convertFromScrollbarToContainingView(const Scrollbar* scrollbar, const IntPoint& scrollbarPoint) const
    {
        return scrollbar->Widget::convertToContainingView(scrollbarPoint);
    }
    virtual IntPoint convertFromContainingViewToScrollbar(const Scrollbar* scrollbar, const IntPoint& parentPoint) const
    {
        return scrollbar->Widget::convertFromContainingView(parentPoint);
    }

    virtual Scrollbar* horizontalScrollbar() const { return 0; }
    virtual Scrollbar* verticalScrollbar() const { return 0; }

    virtual IntPoint scrollPosition() const { ASSERT_NOT_REACHED(); return IntPoint(); }
    virtual IntPoint minimumScrollPosition() const { ASSERT_NOT_REACHED(); return IntPoint(); }
    virtual IntPoint maximumScrollPosition() const { ASSERT_NOT_REACHED(); return IntPoint(); }
    virtual IntRect visibleContentRect(bool /*includeScrollbars*/ = false) const { ASSERT_NOT_REACHED(); return IntRect(); }
    virtual int visibleHeight() const { ASSERT_NOT_REACHED(); return 0; }
    virtual int visibleWidth() const { ASSERT_NOT_REACHED(); return 0; }
    virtual IntSize contentsSize() const { ASSERT_NOT_REACHED(); return IntSize(); }
    virtual IntSize overhangAmount() const { ASSERT_NOT_REACHED(); return IntSize(); }
    virtual IntPoint currentMousePosition() const { return IntPoint(); }

    virtual bool shouldSuspendScrollAnimations() const { return true; }
    virtual void scrollbarStyleChanged(int /*newStyle*/, bool /*forceUpdate*/) { }
    virtual void setVisibleScrollerThumbRect(const IntRect&) { }

    virtual bool isOnActivePage() const { ASSERT_NOT_REACHED(); return true; }
    
    bool isHorizontalScrollerPinnedToMinimumPosition() const { return !horizontalScrollbar() || scrollPosition(horizontalScrollbar()) <= minimumScrollPosition().x(); }
    bool isHorizontalScrollerPinnedToMaximumPosition() const { return !horizontalScrollbar() || scrollPosition(horizontalScrollbar()) >= maximumScrollPosition().x(); }
    bool isVerticalScrollerPinnedToMinimumPosition() const { return !verticalScrollbar() || scrollPosition(verticalScrollbar()) <= minimumScrollPosition().y(); }
    bool isVerticalScrollerPinnedToMaximumPosition() const { return !verticalScrollbar() || scrollPosition(verticalScrollbar()) >= maximumScrollPosition().y(); }

    // Note that this only returns scrollable areas that can actually be scrolled.
    virtual ScrollableArea* enclosingScrollableArea() const = 0;

    bool isPinnedInBothDirections(const IntSize&) const;
    bool isPinnedHorizontallyInDirection(int horizontalScrollDelta) const;
    bool isPinnedVerticallyInDirection(int verticalScrollDelta) const;

    virtual bool shouldRubberBandInDirection(ScrollDirection) const { return true; }

    virtual void disconnectFromPage() { }

    virtual bool scrollAnimatorEnabled() const { return false; }

    // NOTE: Only called from Internals for testing.
    void setScrollOffsetFromInternals(const IntPoint&);

protected:
    ScrollableArea();
    virtual ~ScrollableArea();

    void setScrollOrigin(const IntPoint&);
    void setScrollOriginX(int);
    void setScrollOriginY(int);
    void resetScrollOriginChanged() { m_scrollOriginChanged = false; }

    virtual void invalidateScrollbarRect(Scrollbar*, const IntRect&) = 0;
    virtual void invalidateScrollCornerRect(const IntRect&) = 0;

#if USE(ACCELERATED_COMPOSITING)
    virtual GraphicsLayer* layerForHorizontalScrollbar() const { return 0; }
    virtual GraphicsLayer* layerForVerticalScrollbar() const { return 0; }
    virtual GraphicsLayer* layerForScrollCorner() const { return 0; }
#if ENABLE(RUBBER_BANDING)
    virtual GraphicsLayer* layerForOverhangAreas() const { return 0; }
#endif
#endif
    bool hasLayerForHorizontalScrollbar() const;
    bool hasLayerForVerticalScrollbar() const;
    bool hasLayerForScrollCorner() const;

private:
    // NOTE: Only called from the ScrollAnimator.
    friend class ScrollAnimator;
    void setScrollOffsetFromAnimation(const IntPoint&);

    mutable OwnPtr<ScrollAnimator> m_scrollAnimator;
    bool m_constrainsScrollingToContentEdge : 1;

    bool m_inLiveResize : 1;

    unsigned m_verticalScrollElasticity : 2; // ScrollElasticity
    unsigned m_horizontalScrollElasticity : 2; // ScrollElasticity

    unsigned m_scrollbarOverlayStyle : 2; // ScrollbarOverlayStyle

    // There are 8 possible combinations of writing mode and direction. Scroll origin will be non-zero in the x or y axis
    // if there is any reversed direction or writing-mode. The combinations are:
    // writing-mode / direction     scrollOrigin.x() set    scrollOrigin.y() set
    // horizontal-tb / ltr          NO                      NO
    // horizontal-tb / rtl          YES                     NO
    // horizontal-bt / ltr          NO                      YES
    // horizontal-bt / rtl          YES                     YES
    // vertical-lr / ltr            NO                      NO
    // vertical-lr / rtl            NO                      YES
    // vertical-rl / ltr            YES                     NO
    // vertical-rl / rtl            YES                     YES
    IntPoint m_scrollOrigin;

    bool m_scrollOriginChanged;
};

} // namespace WebCore

#endif // ScrollableArea_h
