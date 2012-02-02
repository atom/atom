/*
 * Copyright (C) 2003, 2004, 2005 Apple Computer, Inc.  All rights reserved.
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
#import <JavaScriptCore/WebKitAvailability.h>

@class NSError;
@class WebFrame;
@class WebScriptObject;
@class WebView;

/*!
    @category WebFrameLoadDelegate
    @discussion A WebView's WebFrameLoadDelegate tracks the loading progress of its frames.
    When a data source of a frame starts to load, the data source is considered "provisional".
    Once at least one byte is received, the data source is considered "committed". This is done
    so the contents of the frame will not be lost if the new data source fails to successfully load.
*/
@interface NSObject (WebFrameLoadDelegate)

/*!
    @method webView:didStartProvisionalLoadForFrame:
    @abstract Notifies the delegate that the provisional load of a frame has started
    @param webView The WebView sending the message
    @param frame The frame for which the provisional load has started
    @discussion This method is called after the provisional data source of a frame
    has started to load.
*/
- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame;

/*!
    @method webView:didReceiveServerRedirectForProvisionalLoadForFrame:
    @abstract Notifies the delegate that a server redirect occurred during the provisional load
    @param webView The WebView sending the message
    @param frame The frame for which the redirect occurred
*/
- (void)webView:(WebView *)sender didReceiveServerRedirectForProvisionalLoadForFrame:(WebFrame *)frame;

/*!
    @method webView:didFailProvisionalLoadWithError:forFrame:
    @abstract Notifies the delegate that the provisional load has failed
    @param webView The WebView sending the message
    @param error The error that occurred
    @param frame The frame for which the error occurred
    @discussion This method is called after the provisional data source has failed to load.
    The frame will continue to display the contents of the committed data source if there is one.
*/
- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;

/*!
    @method webView:didCommitLoadForFrame:
    @abstract Notifies the delegate that the load has changed from provisional to committed
    @param webView The WebView sending the message
    @param frame The frame for which the load has committed
    @discussion This method is called after the provisional data source has become the
    committed data source.

    In some cases, a single load may be committed more than once. This happens
    in the case of multipart/x-mixed-replace, also known as "server push". In this case,
    a single location change leads to multiple documents that are loaded in sequence. When
    this happens, a new commit will be sent for each document.
*/
- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame;

/*!
    @method webView:didReceiveTitle:forFrame:
    @abstract Notifies the delegate that the page title for a frame has been received
    @param webView The WebView sending the message
    @param title The new page title
    @param frame The frame for which the title has been received
    @discussion The title may update during loading; clients should be prepared for this.
*/
- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame;

/*!
    @method webView:didReceiveIcon:forFrame:
    @abstract Notifies the delegate that a page icon image for a frame has been received
    @param webView The WebView sending the message
    @param image The icon image. Also known as a "favicon".
    @param frame The frame for which a page icon has been received
*/
- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame;

/*!
    @method webView:didFinishLoadForFrame:
    @abstract Notifies the delegate that the committed load of a frame has completed
    @param webView The WebView sending the message
    @param frame The frame that finished loading
    @discussion This method is called after the committed data source of a frame has successfully loaded
    and will only be called when all subresources such as images and stylesheets are done loading.
    Plug-In content and JavaScript-requested loads may occur after this method is called.
*/
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;

/*!
    @method webView:didFailLoadWithError:forFrame:
    @abstract Notifies the delegate that the committed load of a frame has failed
    @param webView The WebView sending the message
    @param error The error that occurred
    @param frame The frame that failed to load
    @discussion This method is called after a data source has committed but failed to completely load.
*/
- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;

/*!
    @method webView:didChangeLocationWithinPageForFrame:
    @abstract Notifies the delegate that the scroll position in a frame has changed
    @param webView The WebView sending the message
    @param frame The frame that scrolled
    @discussion This method is called when anchors within a page have been clicked.
*/
- (void)webView:(WebView *)sender didChangeLocationWithinPageForFrame:(WebFrame *)frame;

/*!
    @method webView:willPerformClientRedirectToURL:delay:fireDate:forFrame:
    @abstract Notifies the delegate that a frame will perform a client-side redirect
    @param webView The WebView sending the message
    @param URL The URL to be redirected to
    @param seconds Seconds in which the redirect will happen
    @param date The fire date
    @param frame The frame on which the redirect will occur
    @discussion This method can be used to continue progress feedback while a client-side
    redirect is pending.
*/
- (void)webView:(WebView *)sender willPerformClientRedirectToURL:(NSURL *)URL delay:(NSTimeInterval)seconds fireDate:(NSDate *)date forFrame:(WebFrame *)frame;

/*!
    @method webView:didCancelClientRedirectForFrame:
    @abstract Notifies the delegate that a pending client-side redirect has been cancelled
    @param webView The WebView sending the message
    @param frame The frame for which the pending redirect was cancelled
    @discussion A client-side redirect can be cancelled if a frame changes location before the timeout.
*/
- (void)webView:(WebView *)sender didCancelClientRedirectForFrame:(WebFrame *)frame;

/*!
    @method webView:willCloseFrame:
    @abstract Notifies the delegate that a frame will be closed
    @param webView The WebView sending the message
    @param frame The frame that will be closed
    @discussion This method is called right before WebKit is done with the frame
    and the objects that it contains.
*/
- (void)webView:(WebView *)sender willCloseFrame:(WebFrame *)frame;

/*!
    @method webView:didClearWindowObject:forFrame:
    @abstract Notifies the delegate that the JavaScript window object in a frame has 
    been cleared in preparation for a new load. This is the preferred place to set custom 
    properties on the window object using the WebScriptObject and JavaScriptCore APIs.
    @param webView The webView sending the message.
    @param windowObject The WebScriptObject representing the frame's JavaScript window object.
    @param frame The WebFrame to which windowObject belongs.
    @discussion If a delegate implements both webView:didClearWindowObject:forFrame:
    and webView:windowScriptObjectAvailable:, only webView:didClearWindowObject:forFrame: 
    will be invoked. This enables a delegate to implement both methods for backwards 
    compatibility with older versions of WebKit.
*/
- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame;

/*!
    @method webView:windowScriptObjectAvailable:
    @abstract Notifies the delegate that the scripting object for a page is available.  This is called
    before the page is loaded.  It may be useful to allow delegates to bind native objects to the window.
    @param webView The webView sending the message.
    @param windowScriptObject The WebScriptObject for the window in the scripting environment.
    @discussion This method is deprecated. Consider using webView:didClearWindowObject:forFrame:
    instead.
*/
- (void)webView:(WebView *)webView windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0);

@end
