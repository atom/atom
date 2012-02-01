/*
 * Copyright (C) 2004 Apple Computer, Inc.  All rights reserved.
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

#import <Cocoa/Cocoa.h>

/*!
    This informal protocol enables a plug-in to request that its containing application
    perform certain operations.
*/

@interface NSObject (WebPlugInContainer)

/*!
    @method webPlugInContainerLoadRequest:inFrame:
    @abstract Tell the application to show a URL in a target frame
    @param request The request to be loaded.
    @param target The target frame. If the frame with the specified target is not
    found, a new window is opened and the main frame of the new window is named
    with the specified target.  If nil is specified, the frame that contains
    the applet is targeted.
*/
- (void)webPlugInContainerLoadRequest:(NSURLRequest *)request inFrame:(NSString *)target;

/*!
    @method webPlugInContainerShowStatus:
    @abstract Tell the application to show the specified status message.
    @param message The string to be shown.
*/
- (void)webPlugInContainerShowStatus:(NSString *)message;

/*!
    @method webPlugInContainerSelectionColor
    @result Returns the color that should be used for any special drawing when
    plug-in is selected.
*/
- (NSColor *)webPlugInContainerSelectionColor;

/*!
    @method webFrame
    @discussion The webFrame method allows the plug-in to access the WebFrame that
    contains the plug-in.  This method will not be implemented by containers that 
    are not WebKit based.
    @result Return the WebFrame that contains the plug-in.
*/
- (WebFrame *)webFrame;

@end
