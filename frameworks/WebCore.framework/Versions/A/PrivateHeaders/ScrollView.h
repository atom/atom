/*
 * Copyright (C) 2004, 2006, 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) 2009 Holger Hans Peter Freyther
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

#ifndef ScrollView_h
#define ScrollView_h

#include "IntRect.h"
#include "Scrollbar.h"
#include "ScrollableArea.h"
#include "ScrollTypes.h"
#include "Widget.h"

#include <wtf/HashSet.h>

#if PLATFORM(MAC) && defined __OBJC__
@protocol WebCoreFrameScrollView;
#endif

#if PLATFORM(WX)
class wxScrollWinEvent;
#endif

namespace WebCore {

class HostWindow;
class Scrollbar;

class ScrollView : public Widget, public ScrollableArea {
public:
    ~ScrollView();

    // ScrollableArea functions.  FrameView overrides the others.
    virtual int scrollSize(ScrollbarOrientation orientation) const;
    virtual int scrollPosition(Scrollbar*) const;
    virtual void setScrollOffset(const IntPoint&);
    virtual void notifyPageThatContentAreaWillPaint() const;
    virtual bool isScrollCornerVisible() const;
    virtual void scrollbarStyleChanged(int newStyle, bool forceUpdate);

    // NOTE: This should only be called by the overriden setScrollOffset from ScrollableArea.
    virtual void scrollTo(const IntSize& newOffset);

    // The window thats hosts the ScrollView. The ScrollView will communicate scrolls and repaints to the
    // host window in the window's coordinate space.
    virtual HostWindow* hostWindow() const = 0;

    // Returns a clip rect in host window coordinates. Used to clip the blit on a scroll.
    virtual IntRect windowClipRect(bool clipToContents = true) const = 0;

    // Functions for child manipulation and inspection.
    const HashSet<RefPtr<Widget> >* children() const { return &m_children; }
    void addChild(PassRefPtr<Widget>);
    void removeChild(Widget*);
    
    // If the scroll view does not use a native widget, then it will have cross-platform Scrollbars. These functions
    // can be used to obtain those scrollbars.
    virtual Scrollbar* horizontalScrollbar() const { return m_horizontalScrollbar.get(); }
    virtual Scrollbar* verticalScrollbar() const { return m_verticalScrollbar.get(); }
    bool isScrollViewScrollbar(const Widget* child) const { return horizontalScrollbar() == child || verticalScrollbar() == child; }

    void positionScrollbarLayers();

    // Functions for setting and retrieving the scrolling mode in each axis (horizontal/vertical). The mode has values of
    // AlwaysOff, AlwaysOn, and Auto. AlwaysOff means never show a scrollbar, AlwaysOn means always show a scrollbar.
    // Auto means show a scrollbar only when one is needed.
    // Note that for platforms with native widgets, these modes are considered advisory. In other words the underlying native
    // widget may choose not to honor the requested modes.
    void setScrollbarModes(ScrollbarMode horizontalMode, ScrollbarMode verticalMode, bool horizontalLock = false, bool verticalLock = false);
    void setHorizontalScrollbarMode(ScrollbarMode mode, bool lock = false) { setScrollbarModes(mode, verticalScrollbarMode(), lock, verticalScrollbarLock()); }
    void setVerticalScrollbarMode(ScrollbarMode mode, bool lock = false) { setScrollbarModes(horizontalScrollbarMode(), mode, horizontalScrollbarLock(), lock); };
    void scrollbarModes(ScrollbarMode& horizontalMode, ScrollbarMode& verticalMode) const;
    ScrollbarMode horizontalScrollbarMode() const { ScrollbarMode horizontal, vertical; scrollbarModes(horizontal, vertical); return horizontal; }
    ScrollbarMode verticalScrollbarMode() const { ScrollbarMode horizontal, vertical; scrollbarModes(horizontal, vertical); return vertical; }

    void setHorizontalScrollbarLock(bool lock = true) { m_horizontalScrollbarLock = lock; }
    bool horizontalScrollbarLock() const { return m_horizontalScrollbarLock; }
    void setVerticalScrollbarLock(bool lock = true) { m_verticalScrollbarLock = lock; }
    bool verticalScrollbarLock() const { return m_verticalScrollbarLock; }

    void setScrollingModesLock(bool lock = true) { m_horizontalScrollbarLock = m_verticalScrollbarLock = lock; }

    virtual void setCanHaveScrollbars(bool);
    bool canHaveScrollbars() const { return horizontalScrollbarMode() != ScrollbarAlwaysOff || verticalScrollbarMode() != ScrollbarAlwaysOff; }

    virtual bool avoidScrollbarCreation() const { return false; }

    virtual void setScrollbarOverlayStyle(ScrollbarOverlayStyle);

    // By default you only receive paint events for the area that is visible. In the case of using a
    // tiled backing store, this function can be set, so that the view paints the entire contents.
    bool paintsEntireContents() const { return m_paintsEntireContents; }
    void setPaintsEntireContents(bool);

    // By default, paint events are clipped to the visible area.  If set to
    // false, paint events are no longer clipped.  paintsEntireContents() implies !clipsRepaints().
    bool clipsRepaints() const { return m_clipsRepaints; }
    void setClipsRepaints(bool);

    // By default programmatic scrolling is handled by WebCore and not by the UI application.
    // In the case of using a tiled backing store, this mode can be set, so that the scroll requests
    // are delegated to the UI application.
    bool delegatesScrolling() const { return m_delegatesScrolling; }
    void setDelegatesScrolling(bool);

    // Overridden by FrameView to create custom CSS scrollbars if applicable.
    virtual PassRefPtr<Scrollbar> createScrollbar(ScrollbarOrientation);

    // If the prohibits scrolling flag is set, then all scrolling in the view (even programmatic scrolling) is turned off.
    void setProhibitsScrolling(bool b) { m_prohibitsScrolling = b; }
    bool prohibitsScrolling() const { return m_prohibitsScrolling; }

    // Whether or not a scroll view will blit visible contents when it is scrolled. Blitting is disabled in situations
    // where it would cause rendering glitches (such as with fixed backgrounds or when the view is partially transparent).
    void setCanBlitOnScroll(bool);
    bool canBlitOnScroll() const;

    // The visible content rect has a location that is the scrolled offset of the document. The width and height are the viewport width
    // and height. By default the scrollbars themselves are excluded from this rectangle, but an optional boolean argument allows them to be
    // included.
    // In the situation the client is responsible for the scrolling (ie. with a tiled backing store) it is possible to use
    // the setFixedVisibleContentRect instead for the mainframe, though this must be updated manually, e.g just before resuming the page
    // which usually will happen when panning, pinching and rotation ends, or when scale or position are changed manually.
    virtual IntRect visibleContentRect(bool includeScrollbars = false) const;
    virtual void setFixedVisibleContentRect(const IntRect& visibleContentRect) { m_fixedVisibleContentRect = visibleContentRect; }
    int visibleWidth() const { return visibleContentRect().width(); }
    int visibleHeight() const { return visibleContentRect().height(); }

    // Functions for getting/setting the size webkit should use to layout the contents. By default this is the same as the visible
    // content size. Explicitly setting a layout size value will cause webkit to layout the contents using this size instead.
    int layoutWidth() const;
    int layoutHeight() const;
    IntSize fixedLayoutSize() const;
    void setFixedLayoutSize(const IntSize&);
    bool useFixedLayout() const;
    void setUseFixedLayout(bool enable);
    
    // Functions for getting/setting the size of the document contained inside the ScrollView (as an IntSize or as individual width and height
    // values).
    IntSize contentsSize() const; // Always at least as big as the visibleWidth()/visibleHeight().
    int contentsWidth() const { return contentsSize().width(); }
    int contentsHeight() const { return contentsSize().height(); }
    virtual void setContentsSize(const IntSize&);

    // Functions for querying the current scrolled position (both as a point, a size, or as individual X and Y values).
    IntPoint scrollPosition() const { return visibleContentRect().location(); }
    IntSize scrollOffset() const { return visibleContentRect().location() - IntPoint(); } // Gets the scrolled position as an IntSize. Convenient for adding to other sizes.
    IntPoint maximumScrollPosition() const; // The maximum position we can be scrolled to.
    IntPoint minimumScrollPosition() const; // The minimum position we can be scrolled to.
    // Adjust the passed in scroll position to keep it between the minimum and maximum positions.
    IntPoint adjustScrollPositionWithinRange(const IntPoint&) const; 
    int scrollX() const { return scrollPosition().x(); }
    int scrollY() const { return scrollPosition().y(); }

    IntSize overhangAmount() const;

    void cacheCurrentScrollPosition() { m_cachedScrollPosition = scrollPosition(); }
    IntPoint cachedScrollPosition() const { return m_cachedScrollPosition; }

    // Functions for scrolling the view.
    void setScrollPosition(const IntPoint&);
    void scrollBy(const IntSize& s) { return setScrollPosition(scrollPosition() + s); }

    // This function scrolls by lines, pages or pixels.
    bool scroll(ScrollDirection, ScrollGranularity);
    
    // A logical scroll that just ends up calling the corresponding physical scroll() based off the document's writing mode.
    bool logicalScroll(ScrollLogicalDirection, ScrollGranularity);

    // Scroll the actual contents of the view (either blitting or invalidating as needed).
    void scrollContents(const IntSize& scrollDelta);

    // This gives us a means of blocking painting on our scrollbars until the first layout has occurred.
    void setScrollbarsSuppressed(bool suppressed, bool repaintOnUnsuppress = false);
    bool scrollbarsSuppressed() const { return m_scrollbarsSuppressed; }

    IntPoint rootViewToContents(const IntPoint&) const;
    IntPoint contentsToRootView(const IntPoint&) const;
    IntRect rootViewToContents(const IntRect&) const;
    IntRect contentsToRootView(const IntRect&) const;

    // Event coordinates are assumed to be in the coordinate space of a window that contains
    // the entire widget hierarchy. It is up to the platform to decide what the precise definition
    // of containing window is. (For example on Mac it is the containing NSWindow.)
    IntPoint windowToContents(const IntPoint&) const;
    IntPoint contentsToWindow(const IntPoint&) const;
    IntRect windowToContents(const IntRect&) const;
    IntRect contentsToWindow(const IntRect&) const;

    // Functions for converting to and from screen coordinates.
    IntRect contentsToScreen(const IntRect&) const;
    IntPoint screenToContents(const IntPoint&) const;

    // The purpose of this function is to answer whether or not the scroll view is currently visible. Animations and painting updates can be suspended if
    // we know that we are either not in a window right now or if that window is not visible.
    bool isOffscreen() const;
    
    // These functions are used to enable scrollbars to avoid window resizer controls that overlap the scroll view. This happens on Mac
    // for example.
    virtual IntRect windowResizerRect() const { return IntRect(); }
    bool containsScrollbarsAvoidingResizer() const;
    void adjustScrollbarsAvoidingResizerCount(int overlapDelta);
    void windowResizerRectChanged();

    virtual void setParent(ScrollView*); // Overridden to update the overlapping scrollbar count.

    // Called when our frame rect changes (or the rect/scroll position of an ancestor changes).
    virtual void frameRectsChanged();
    
    // Widget override to update our scrollbars and notify our contents of the resize.
    virtual void setFrameRect(const IntRect&);

    // For platforms that need to hit test scrollbars from within the engine's event handlers (like Win32).
    Scrollbar* scrollbarAtPoint(const IntPoint& windowPoint);

    // This function exists for scrollviews that need to handle wheel events manually.
    // On Mac the underlying NSScrollView just does the scrolling, but on other platforms
    // (like Windows), we need this function in order to do the scroll ourselves.
    bool wheelEvent(const PlatformWheelEvent&);
#if ENABLE(GESTURE_EVENTS)
    void gestureEvent(const PlatformGestureEvent&);
#endif

    IntPoint convertChildToSelf(const Widget* child, const IntPoint& point) const
    {
        IntPoint newPoint = point;
        if (!isScrollViewScrollbar(child))
            newPoint = point - scrollOffset();
        newPoint.moveBy(child->location());
        return newPoint;
    }

    IntPoint convertSelfToChild(const Widget* child, const IntPoint& point) const
    {
        IntPoint newPoint = point;
        if (!isScrollViewScrollbar(child))
            newPoint = point + scrollOffset();
        newPoint.moveBy(-child->location());
        return newPoint;
    }

    // Widget override. Handles painting of the contents of the view as well as the scrollbars.
    virtual void paint(GraphicsContext*, const IntRect&);
    void paintScrollbars(GraphicsContext*, const IntRect&);

    // Widget overrides to ensure that our children's visibility status is kept up to date when we get shown and hidden.
    virtual void show();
    virtual void hide();
    virtual void setParentVisible(bool);
    
    // Pan scrolling.
    static const int noPanScrollRadius = 15;
    void addPanScrollIcon(const IntPoint&);
    void removePanScrollIcon();
    void paintPanScrollIcon(GraphicsContext*);

    virtual bool isPointInScrollbarCorner(const IntPoint&);
    virtual bool scrollbarCornerPresent() const;
    virtual IntRect scrollCornerRect() const;
    virtual void paintScrollCorner(GraphicsContext*, const IntRect& cornerRect);

    virtual IntRect convertFromScrollbarToContainingView(const Scrollbar*, const IntRect&) const;
    virtual IntRect convertFromContainingViewToScrollbar(const Scrollbar*, const IntRect&) const;
    virtual IntPoint convertFromScrollbarToContainingView(const Scrollbar*, const IntPoint&) const;
    virtual IntPoint convertFromContainingViewToScrollbar(const Scrollbar*, const IntPoint&) const;

    bool containsScrollableAreaWithOverlayScrollbars() const { return m_containsScrollableAreaWithOverlayScrollbars; }
    void setContainsScrollableAreaWithOverlayScrollbars(bool contains) { m_containsScrollableAreaWithOverlayScrollbars = contains; }

    void calculateAndPaintOverhangAreas(GraphicsContext*, const IntRect& dirtyRect);

protected:
    ScrollView();

    virtual void repaintContentRectangle(const IntRect&, bool now = false);
    virtual void paintContents(GraphicsContext*, const IntRect& damageRect) = 0;

    void calculateOverhangAreasForPainting(IntRect& horizontalOverhangRect, IntRect& verticalOverhangRect);
    virtual void paintOverhangAreas(GraphicsContext*, const IntRect& horizontalOverhangArea, const IntRect& verticalOverhangArea, const IntRect& dirtyRect);

    virtual void visibleContentsResized() = 0;

    IntRect fixedVisibleContentRect() const { return m_fixedVisibleContentRect; }

    // These functions are used to create/destroy scrollbars.
    void setHasHorizontalScrollbar(bool);
    void setHasVerticalScrollbar(bool);

    virtual void updateScrollCorner();
    virtual void invalidateScrollCornerRect(const IntRect&);

    // Scroll the content by blitting the pixels.
    virtual bool scrollContentsFastPath(const IntSize& scrollDelta, const IntRect& rectToScroll, const IntRect& clipRect);
    // Scroll the content by invalidating everything.
    virtual void scrollContentsSlowPath(const IntRect& updateRect);

    void setScrollOrigin(const IntPoint&, bool updatePositionAtAll, bool updatePositionSynchronously);

    // Subclassed by FrameView to check the writing-mode of the document.
    virtual bool isVerticalDocument() const { return true; }
    virtual bool isFlippedDocument() const { return false; }

private:
    RefPtr<Scrollbar> m_horizontalScrollbar;
    RefPtr<Scrollbar> m_verticalScrollbar;
    ScrollbarMode m_horizontalScrollbarMode;
    ScrollbarMode m_verticalScrollbarMode;

    bool m_horizontalScrollbarLock;
    bool m_verticalScrollbarLock;

    bool m_prohibitsScrolling;

    HashSet<RefPtr<Widget> > m_children;

    // This bool is unused on Mac OS because we directly ask the platform widget
    // whether it is safe to blit on scroll.
    bool m_canBlitOnScroll;

    IntRect m_fixedVisibleContentRect;
    IntSize m_scrollOffset; // FIXME: Would rather store this as a position, but we will wait to make this change until more code is shared.
    IntPoint m_cachedScrollPosition;
    IntSize m_fixedLayoutSize;
    IntSize m_contentsSize;

    int m_scrollbarsAvoidingResizer;
    bool m_scrollbarsSuppressed;

    bool m_inUpdateScrollbars;
    unsigned m_updateScrollbarsPass;

    IntPoint m_panScrollIconPoint;
    bool m_drawPanScrollIcon;
    bool m_useFixedLayout;

    bool m_paintsEntireContents;
    bool m_clipsRepaints;
    bool m_delegatesScrolling;

    bool m_containsScrollableAreaWithOverlayScrollbars;

    void init();
    void destroy();

    // Called to update the scrollbars to accurately reflect the state of the view.
    void updateScrollbars(const IntSize& desiredOffset);
    IntRect rectToCopyOnScroll() const;

    // Called when the scroll position within this view changes.  FrameView overrides this to generate repaint invalidations.
    virtual void repaintFixedElementsAfterScrolling() {}

    void platformInit();
    void platformDestroy();
    void platformAddChild(Widget*);
    void platformRemoveChild(Widget*);
    void platformSetScrollbarModes();
    void platformScrollbarModes(ScrollbarMode& horizontal, ScrollbarMode& vertical) const;
    void platformSetCanBlitOnScroll(bool);
    bool platformCanBlitOnScroll() const;
    IntRect platformVisibleContentRect(bool includeScrollbars) const;
    void platformSetContentsSize();
    IntRect platformContentsToScreen(const IntRect&) const;
    IntPoint platformScreenToContents(const IntPoint&) const;
    void platformSetScrollPosition(const IntPoint&);
    bool platformScroll(ScrollDirection, ScrollGranularity);
    void platformSetScrollbarsSuppressed(bool repaintOnUnsuppress);
    void platformRepaintContentRectangle(const IntRect&, bool now);
    bool platformIsOffscreen() const;
    void platformSetScrollbarOverlayStyle(ScrollbarOverlayStyle);
   
    void platformSetScrollOrigin(const IntPoint&, bool updatePositionAtAll, bool updatePositionSynchronously);

#if PLATFORM(MAC) && defined __OBJC__
public:
    NSView* documentView() const;

private:
    NSScrollView<WebCoreFrameScrollView>* scrollView() const;
#endif

#if PLATFORM(WX)
public:
    virtual void setPlatformWidget(wxWindow*);
    void adjustScrollbars(int x = -1, int y = -1, bool refresh = true);
private:
    class ScrollViewPrivate;
    ScrollViewPrivate* m_data;
#endif

}; // class ScrollView

} // namespace WebCore

#endif // ScrollView_h
