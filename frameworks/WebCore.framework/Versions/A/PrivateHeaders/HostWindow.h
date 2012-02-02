/*
 * Copyright (C) 2008 Apple Inc.  All rights reserved.
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

#ifndef HostWindow_h
#define HostWindow_h

#include "Widget.h"

namespace WebCore {

class Cursor;

class HostWindow {
    WTF_MAKE_NONCOPYABLE(HostWindow); WTF_MAKE_FAST_ALLOCATED;
public:
    HostWindow() { }
    virtual ~HostWindow() { }

    // Requests the host invalidate the root view, not the contents. If immediate is true do so synchronously, otherwise async.
    virtual void invalidateRootView(const IntRect& updateRect, bool immediate) = 0;

    // Requests the host invalidate the contents and the root view. If immediate is true do so synchronously, otherwise async.
    virtual void invalidateContentsAndRootView(const IntRect& updateRect, bool immediate) = 0;

    // Requests the host scroll backingstore by the specified delta, rect to scroll, and clip rect.
    virtual void scroll(const IntSize& scrollDelta, const IntRect& rectToScroll, const IntRect& clipRect) = 0;

    // Requests the host invalidate the contents, not the root view. This is the slow path for scrolling.
    virtual void invalidateContentsForSlowScroll(const IntRect& updateRect, bool immediate) = 0;

#if USE(TILED_BACKING_STORE)
    // Requests the host to do the actual scrolling. This is only used in combination with a tiled backing store.
    virtual void delegatedScrollRequested(const IntPoint& scrollPoint) = 0;
#endif

    // Methods for doing coordinate conversions to and from screen coordinates.
    virtual IntPoint screenToRootView(const IntPoint&) const = 0;
    virtual IntRect rootViewToScreen(const IntRect&) const = 0;

    // Method for retrieving the native client of the page.
    virtual PlatformPageClient platformPageClient() const = 0;
    
    // To notify WebKit of scrollbar mode changes.
    virtual void scrollbarsModeDidChange() const = 0;

    // Request that the cursor change.
    virtual void setCursor(const Cursor&) = 0;

    virtual void setCursorHiddenUntilMouseMoves(bool) = 0;

#if ENABLE(REQUEST_ANIMATION_FRAME)
    virtual void scheduleAnimation() = 0;
#endif
};

} // namespace WebCore

#endif // HostWindow_h
