/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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

#if ENABLE(VIDEO)

#import <AppKit/NSButton.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSTrackingArea.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSWindowController.h>

namespace WebCore {
    class HTMLMediaElement;
}

@protocol WebVideoFullscreenHUDWindowControllerDelegate;

@interface WebVideoFullscreenHUDWindowController : NSWindowController
{
    id <WebVideoFullscreenHUDWindowControllerDelegate> _delegate;
    NSTimer *_timelineUpdateTimer;
    NSTrackingArea *_area;
    BOOL _mouseIsInHUD;
    BOOL _isEndingFullscreen;
    BOOL _isScrubbing;

    NSControl *_timeline;
    NSTextField *_remainingTimeText;
    NSTextField *_elapsedTimeText;
    NSControl *_volumeSlider;
    NSButton *_playButton;
}

- (id <WebVideoFullscreenHUDWindowControllerDelegate>)delegate;
- (void)setDelegate:(id <WebVideoFullscreenHUDWindowControllerDelegate>)delegate;
- (void)fadeWindowIn;
- (void)fadeWindowOut;
- (void)closeWindow;
- (void)updateRate;

@end

@protocol WebVideoFullscreenHUDWindowControllerDelegate <NSObject>
- (void)requestExitFullscreen;
- (WebCore::HTMLMediaElement*)mediaElement;
@end

#endif
