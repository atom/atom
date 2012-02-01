/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ScrollingCoordinator_h
#define ScrollingCoordinator_h

#if ENABLE(THREADED_SCROLLING)

#include "GraphicsLayer.h"
#include "IntRect.h"
#include <wtf/Forward.h>
#include <wtf/ThreadSafeRefCounted.h>
#include <wtf/Threading.h>

#if PLATFORM(MAC)
#include <wtf/RetainPtr.h>
#endif

namespace WebCore {

class FrameView;
class GraphicsLayer;
class Page;
class PlatformWheelEvent;

#if ENABLE(GESTURE_EVENTS)
class PlatformGestureEvent;
#endif

class ScrollingCoordinator : public ThreadSafeRefCounted<ScrollingCoordinator> {
public:
    static PassRefPtr<ScrollingCoordinator> create(Page*);
    ~ScrollingCoordinator();

    void pageDestroyed();

    // Should be called whenever the scroll layer for the given frame view changes.
    void frameViewScrollLayerDidChange(FrameView*, const GraphicsLayer*);

    // Should be called whenever the horizontal scrollbar layer for the given frame view changes.
    void frameViewHorizontalScrollbarLayerDidChange(FrameView*, GraphicsLayer* horizontalScrollbarLayer);

    // Should be called whenever the horizontal scrollbar layer for the given frame view changes.
    void frameViewVerticalScrollbarLayerDidChange(FrameView*, GraphicsLayer* verticalScrollbarLayer);

    // Should be called whenever the geometry of the given frame view changes,
    // including the visible content rect and the content size.
    void syncFrameViewGeometry(FrameView*);

    // Can be called from any thread. Will try to handle the wheel event on the scrolling thread,
    // and return false if the event must be sent again to the WebCore event handler.
    bool handleWheelEvent(const PlatformWheelEvent&);

#if ENABLE(GESTURE_EVENTS)
    // Can be called from any thread. Will try to handle the gesture event on the scrolling thread,
    // and return false if the event must be sent again to the WebCore event handler.
    bool handleGestureEvent(const PlatformGestureEvent&);
#endif

private:
    explicit ScrollingCoordinator(Page*);

    // FIXME: Once we have a proper thread/run loop abstraction we should get rid of these
    // functions and just use something like scrollingRunLoop()->dispatch(function);
    static bool isScrollingThread();
    static void dispatchOnScrollingThread(const Function<void()>&);

    // The following functions can only be called from the main thread.
    void didUpdateMainFrameScrollPosition();

    // The following functions can only be called from the scrolling thread.
    void scrollByOnScrollingThread(const IntSize& offset);

    // This function must be called with the main frame geometry mutex held.
    void updateMainFrameScrollLayerPositionOnScrollingThread(const FloatPoint&);

private:
    Page* m_page;

    Mutex m_mainFrameGeometryMutex;
    IntRect m_mainFrameVisibleContentRect;
    IntSize m_mainFrameContentsSize;
#if PLATFORM(MAC)
    RetainPtr<PlatformLayer> m_mainFrameScrollLayer;
#endif

    bool m_didDispatchDidUpdateMainFrameScrollPosition;
    IntPoint m_mainFrameScrollPosition;
};

} // namespace WebCore

#endif // ENABLE(THREADED_SCROLLING)

#endif // ScrollingCoordinator_h
