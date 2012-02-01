/*
 * Copyright (C) 2005 Apple Computer, Inc.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <WebKit/WebFrameView.h>

@interface WebFrameView (WebPrivate)

// FIXME: This method was used by Safari 4.0.x and older versions, but has not been used by any other WebKit
// clients to my knowledge, and will not be used by future versions of Safari. It can probably be removed 
// once we no longer need to keep nightly WebKit builds working with Safari 4.0.x and earlier.
/*!
    @method _largestChildWithScrollBars
    @abstract Of the child WebFrameViews that are displaying scroll bars, determines which has the largest area.
    @result A child WebFrameView that is displaying scroll bars, or nil if none.
 */
- (WebFrameView *)_largestChildWithScrollBars;

// FIXME: This method was used by Safari 4.0.x and older versions, but has not been used by any other WebKit
// clients to my knowledge, and will not be used by future versions of Safari. It can probably be removed 
// once we no longer need to keep nightly WebKit builds working with Safari 4.0.x and earlier.
/*!
    @method _hasScrollBars
    @result YES if at least one scroll bar is currently displayed
 */
- (BOOL)_hasScrollBars;

/*!
    @method _largestScrollableChild
    @abstract Of the child WebFrameViews that allow scrolling, determines which has the largest area.
    @result A child WebFrameView that is scrollable, or nil if none.
 */
- (WebFrameView *)_largestScrollableChild;

/*!
    @method _isScrollable
    @result YES if scrolling is currently possible, whether or not scroll bars are currently showing. This
    differs from -allowsScrolling in that the latter method only checks whether scrolling has been
    explicitly disallowed via a call to setAllowsScrolling:NO.
 */
- (BOOL)_isScrollable;

/*!
    @method _contentView
    @result The content view (NSClipView) of the WebFrameView's scroll view.
 */
- (NSClipView *)_contentView;

/*!
    @method _customScrollViewClass
    @result The custom scroll view class that is installed, nil if the default scroll view is being used.
 */
- (Class)_customScrollViewClass;

/*!
    @method _setCustomScrollViewClass:
    @result Switches the WebFrameView's scroll view class, this class needs to be a subclass of WebDynamicScrollBarsView.
    Passing nil will switch back to the default WebDynamicScrollBarsView class.
 */
- (void)_setCustomScrollViewClass:(Class)scrollViewClass;

@end
