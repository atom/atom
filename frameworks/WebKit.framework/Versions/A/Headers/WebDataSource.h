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

#import <WebKit/WebDocument.h>

@class NSMutableURLRequest;
@class NSURLConnection;
@class NSURLRequest;
@class NSURLResponse;
@class WebArchive;
@class WebDataSourcePrivate;
@class WebFrame;
@class WebResource;

/*!
    @class WebDataSource
    @discussion A WebDataSource represents the data associated with a web page.
    A datasource has a WebDocumentRepresentation which holds an appropriate
    representation of the data.  WebDataSources manage a hierarchy of WebFrames.
    WebDataSources are typically related to a view by their containing WebFrame.
*/
@interface WebDataSource : NSObject
{
@private
    WebDataSourcePrivate *_private;
}

/*!
    @method initWithRequest:
    @abstract The designated initializer for WebDataSource.
    @param request The request to use in creating a datasource.
    @result Returns an initialized WebDataSource.
*/
- (id)initWithRequest:(NSURLRequest *)request;

/*!
    @method data
    @discussion The data will be incomplete until the datasource has completely loaded.  
    @result Returns the raw data associated with the datasource.  Returns nil
    if the datasource hasn't loaded any data.
*/
- (NSData *)data;

/*!
    @method representation
    @discussion A representation holds a type specific representation
    of the datasource's data.  The representation class is determined by mapping
    a MIME type to a class.  The representation is created once the MIME type
    of the datasource content has been determined.
    @result Returns the representation associated with this datasource.
    Returns nil if the datasource hasn't created it's representation.
*/
- (id <WebDocumentRepresentation>)representation;

/*!
    @method webFrame
    @result Return the frame that represents this data source.
*/
- (WebFrame *)webFrame;

/*!
    @method initialRequest
    @result Returns a reference to the original request that created the
    datasource.  This request will be unmodified by WebKit. 
*/
- (NSURLRequest *)initialRequest;

/*!
    @method request
    @result Returns the request that was used to create this datasource.
*/
- (NSMutableURLRequest *)request;

/*!
    @method response
    @result returns the WebResourceResponse for the data source.
*/
- (NSURLResponse *)response;

/*!
    @method textEncodingName
    @result Returns either the override encoding, as set on the WebView for this 
    dataSource or the encoding from the response.
*/
- (NSString *)textEncodingName;

/*!
    @method isLoading
    @discussion Returns YES if there are any pending loads.
*/
- (BOOL)isLoading;

/*!
    @method pageTitle
    @result Returns nil or the page title.
*/
- (NSString *)pageTitle;

/*!
    @method unreachableURL
    @discussion This will be non-nil only for dataSources created by calls to the 
    WebFrame method loadAlternateHTMLString:baseURL:forUnreachableURL:.
    @result returns the unreachableURL for which this dataSource is showing alternate content, or nil
*/
- (NSURL *)unreachableURL;

/*!
    @method webArchive
    @result A WebArchive representing the data source, its subresources and child frames.
    @description This method constructs a WebArchive using the original downloaded data.
    In the case of HTML, if the current state of the document is preferred, webArchive should be
    called on the DOM document instead.
*/
- (WebArchive *)webArchive;

/*!
    @method mainResource
    @result A WebResource representing the data source.
    @description This method constructs a WebResource using the original downloaded data.
    This method can be used to construct a WebArchive in case the archive returned by
    WebDataSource's webArchive isn't sufficient.
*/
- (WebResource *)mainResource;

/*!
    @method subresources
    @abstract Returns all the subresources associated with the data source.
    @description The returned array only contains subresources that have fully downloaded.
*/
- (NSArray *)subresources;

/*!
    method subresourceForURL:
    @abstract Returns a subresource for a given URL.
    @param URL The URL of the subresource.
    @description Returns non-nil if the data source has fully downloaded a subresource with the given URL.
*/
- (WebResource *)subresourceForURL:(NSURL *)URL;

/*!
    @method addSubresource:
    @abstract Adds a subresource to the data source.
    @param subresource The subresource to be added.
    @description addSubresource: adds a subresource to the data source's list of subresources.
    Later, if something causes the data source to load the URL of the subresource, the data source
    will load the data from the subresource instead of from the network. For example, if one wants to add
    an image that is already downloaded to a web page, addSubresource: can be called so that the data source
    uses the downloaded image rather than accessing the network. NOTE: If the data source already has a
    subresource with the same URL, addSubresource: will replace it.
*/
- (void)addSubresource:(WebResource *)subresource;

@end
