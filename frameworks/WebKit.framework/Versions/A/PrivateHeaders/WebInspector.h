/*
 * Copyright (C) 2007 Apple Inc.  All rights reserved.
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

#import <Foundation/NSObject.h>

@class WebView;
@class WebInspectorFrontend;

@interface WebInspector : NSObject
{
    WebView *_webView;
    WebInspectorFrontend *_frontend;
}
- (id)initWithWebView:(WebView *)webView;
- (void)webViewClosed;
- (void)show:(id)sender;
- (void)showConsole:(id)sender;
- (void)close:(id)sender;
- (void)attach:(id)sender;
- (void)detach:(id)sender;

- (BOOL)isDebuggingJavaScript;
- (void)toggleDebuggingJavaScript:(id)sender;
- (void)startDebuggingJavaScript:(id)sender;
- (void)stopDebuggingJavaScript:(id)sender;

- (BOOL)isJavaScriptProfilingEnabled;
- (void)setJavaScriptProfilingEnabled:(BOOL)enabled;
- (BOOL)isTimelineProfilingEnabled;
- (void)setTimelineProfilingEnabled:(BOOL)enabled;

- (BOOL)isProfilingJavaScript;
- (void)toggleProfilingJavaScript:(id)sender;
- (void)startProfilingJavaScript:(id)sender;
- (void)stopProfilingJavaScript:(id)sender;
@end
