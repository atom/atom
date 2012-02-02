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

@class WebView;
@class WebDataSource;
@class NSURLAuthenticationChallenge;
@class NSURLResponse;
@class NSURLRequest;

/*!
    @category  WebResourceLoadDelegate
    @discussion Implementors of this protocol will receive messages indicating
    that a resource is about to be loaded, data has been received for a resource,
    an error has been received for a resource, and completion of a resource load.
    Implementors are also given the opportunity to mutate requests before they are sent.
    The various progress methods of this protocol all receive an identifier as the
    parameter.  This identifier can be used to track messages associated with a single
    resource.  For example, a single resource may generate multiple 
    resource:willSendRequest:redirectResponse:fromDataSource: messages as it's URL is redirected.
*/
@interface NSObject (WebResourceLoadDelegate)

/*!
    @method webView:identifierForInitialRequest:fromDataSource:
    @param webView The WebView sending the message.
    @param request The request about to be sent.
    @param dataSource The datasource that initiated the load.
    @discussion An implementor of WebResourceLoadDelegate should provide an identifier
    that can be used to track the load of a single resource.  This identifier will be
    passed as the first argument for all of the other WebResourceLoadDelegate methods.  The
    identifier is useful to track changes to a resources request, which will be
    provided by one or more calls to resource:willSendRequest:redirectResponse:fromDataSource:.
    @result An identifier that will be passed back to the implementor for each callback.
    The identifier will be retained.
*/
- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:resource:willSendRequest:redirectResponse:fromDataSource:
    @discussion This message is sent before a load is initiated.  The request may be modified
    as necessary by the receiver.
    @param webView The WebView sending the message.
    @param identifier An identifier that can be used to track the progress of a resource load across
    multiple call backs.
    @param request The request about to be sent.
    @param redirectResponse If the request is being made in response to a redirect we received,
    the response that conveyed that redirect.
    @param dataSource The dataSource that initiated the load.
    @result Returns the request, which may be mutated by the implementor, although typically
    will be request.
*/
- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:resource:didReceiveAuthenticationChallenge:fromDataSource:
    @abstract Start authentication for the resource, providing a challenge
    @discussion Call useCredential::, continueWithoutCredential or
    cancel on the challenge when done.
    @param challenge The NSURLAuthenticationChallenge to start authentication for
    @discussion If you do not implement this delegate method, WebKit will handle authentication
    automatically by prompting with a sheet on the window that the WebView is associated with.
*/
- (void)webView:(WebView *)sender resource:(id)identifier didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:resource:didCancelAuthenticationChallenge:fromDataSource:
    @abstract Cancel authentication for a given request
    @param challenge The NSURLAuthenticationChallenge for which to cancel authentication
*/
- (void)webView:(WebView *)sender resource:(id)identifier didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:resource:didReceiveResponse:fromDataSource:
    @abstract This message is sent after a response has been received for this load.
    @param webView The WebView sending the message.
    @param identifier An identifier that can be used to track the progress of a resource load across
    multiple call backs.
    @param response The response for the request.
    @param dataSource The dataSource that initiated the load.
    @discussion In some rare cases, multiple responses may be received for a single load.
    This occurs with multipart/x-mixed-replace, or "server push". In this case, the client
    should assume that each new response resets progress so far for the resource back to 0,
    and should check the new response for the expected content length.
*/
- (void)webView:(WebView *)sender resource:(id)identifier didReceiveResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:resource:didReceiveContentLength:fromDataSource:
    @discussion Multiple of these messages may be sent as data arrives.
    @param webView The WebView sending the message.
    @param identifier An identifier that can be used to track the progress of a resource load across
    multiple call backs.
    @param length The amount of new data received.  This is not the total amount, just the new amount received.
    @param dataSource The dataSource that initiated the load.
*/
- (void)webView:(WebView *)sender resource:(id)identifier didReceiveContentLength:(NSInteger)length fromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:resource:didFinishLoadingFromDataSource:
    @discussion This message is sent after a load has successfully completed.
    @param webView The WebView sending the message.
    @param identifier An identifier that can be used to track the progress of a resource load across
    multiple call backs.
    @param dataSource The dataSource that initiated the load.
*/
- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:resource:didFailLoadingWithError:fromDataSource:
    @discussion This message is sent after a load has failed to load due to an error.
    @param webView The WebView sending the message.
    @param identifier An identifier that can be used to track the progress of a resource load across
    multiple call backs.
    @param error The error associated with this load.
    @param dataSource The dataSource that initiated the load.
*/
- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource;

/*!
    @method webView:plugInFailedWithError:dataSource:
    @discussion Called when a plug-in is not found, fails to load or is not available for some reason.
    @param webView The WebView sending the message.
    @param error The plug-in error. In the userInfo dictionary of the error, the object for the
    NSErrorFailingURLKey key is a URL string of the SRC attribute, the object for the WebKitErrorPlugInNameKey
    key is a string of the plug-in's name, the object for the WebKitErrorPlugInPageURLStringKey key is a URL string
    of the PLUGINSPAGE attribute and the object for the WebKitErrorMIMETypeKey key is a string of the TYPE attribute.
    Some, none or all of the mentioned attributes can be present in the userInfo. The error returns nil for userInfo
    when none are present.
    @param dataSource The dataSource that contains the plug-in.
*/
- (void)webView:(WebView *)sender plugInFailedWithError:(NSError *)error dataSource:(WebDataSource *)dataSource;

@end
