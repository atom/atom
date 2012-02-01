/*
 * Copyright (C) 2005, 2008, 2010 Apple Inc. All rights reserved.
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

// This is a Private header (containing SPI), despite the fact that its name
// does not contain the word Private.

#import <AppKit/NSScrollView.h>

// FIXME: <rdar://problem/5898985> Mail currently expects this header to define WebCoreScrollbarAlwaysOn.
extern const int WebCoreScrollbarAlwaysOn;

struct WebDynamicScrollBarsViewPrivate;
@interface WebDynamicScrollBarsView : NSScrollView {
@private
    struct WebDynamicScrollBarsViewPrivate *_private;

#ifndef __OBJC2__
    // We need to pad the class out to its former size.  See <rdar://problem/7814899> for more information.
    char padding[16];
#endif
}

// For use by DumpRenderTree only.
+ (void)setCustomScrollerClass:(Class)scrollerClass;

// This was originally added for Safari's benefit, but Safari has not used it for a long time.
// Perhaps it can be removed.
- (void)setAllowsHorizontalScrolling:(BOOL)flag;

// Determines whether the scrollers should be drawn outside of the content (as in normal scroll views)
// or should overlap the content.
- (void)setAllowsScrollersToOverlapContent:(BOOL)flag;

// These methods hide the scrollers in a way that does not prevent scrolling.
- (void)setAlwaysHideHorizontalScroller:(BOOL)flag;
- (void)setAlwaysHideVerticalScroller:(BOOL)flag;

// These methods return YES if the scrollers are visible, or if the only reason that they are not
// visible is that they have been suppressed by setAlwaysHideHorizontal/VerticalScroller:.
- (BOOL)horizontalScrollingAllowed;
- (BOOL)verticalScrollingAllowed;
@end
