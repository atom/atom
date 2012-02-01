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

@class NSError;
@class WebDataSource;

/*!
    @protocol WebDocumentView
    @discussion Protocol implemented by the document view of WebFrameView
*/
@protocol WebDocumentView <NSObject>

/*!
    @method setDataSource:
    @abstract Called when the corresponding data source has been created.
    @param dataSource The corresponding data source.
*/
- (void)setDataSource:(WebDataSource *)dataSource;

/*!
    @method dataSourceUpdated:
    @abstract Called when the corresponding data source has received data.
    @param dataSource The corresponding data source.
*/
- (void)dataSourceUpdated:(WebDataSource *)dataSource;

/*!
    @method setNeedsLayout:
    @discussion Called when WebKit has determined that the document view needs to layout.
    This method should simply set a flag and call layout from drawRect if the flag is YES.
    @param flag YES to cause a layout, no to not cause a layout.
*/
- (void)setNeedsLayout:(BOOL)flag;

/*!
    @method layout
    @discussion Called when the document view must immediately layout. For simple views,
    setting the frame is a sufficient implementation of this method.
*/
- (void)layout;

/*!
    @method viewWillMoveToHostWindow:
    @param hostWindow The host window for the document view.
    @abstract Called before the host window is set on the parent web view.
*/
- (void)viewWillMoveToHostWindow:(NSWindow *)hostWindow;

/*!
    @method viewDidMoveToHostWindow
    @abstract Called after the host window is set on the parent web view.
*/
- (void)viewDidMoveToHostWindow;

@end


/*!
    @protocol WebDocumentSearching
    @discussion Optional protocol for searching document view of WebFrameView. 
*/
@protocol WebDocumentSearching <NSObject>
/*!
    @method searchFor:direction:caseSensitive:wrap:
    @abstract Searches a document view for a string and highlights the string if it is found.
    @param string The string to search for.
    @param forward YES to search forward, NO to seach backwards.
    @param caseFlag YES to for case-sensitive search, NO for case-insensitive search.
    @param wrapFlag YES to wrap around, NO to avoid wrapping.
    @result YES if found, NO if not found.
*/
- (BOOL)searchFor:(NSString *)string direction:(BOOL)forward caseSensitive:(BOOL)caseFlag wrap:(BOOL)wrapFlag;
@end


/*!
    @protocol WebDocumentText
    @discussion Optional protocol for supporting text operations.
*/
@protocol WebDocumentText <NSObject>

/*!
    @method supportsTextEncoding
    @result YES if the document view support text encoding, NO if it doesn't.
*/
- (BOOL)supportsTextEncoding;

/*!
    @method string
    @result String that represents the entire document.
*/
- (NSString *)string;

/*!
    @method attributedString
    @result Attributed string that represents the entire document.
*/
- (NSAttributedString *)attributedString;

/*!
    @method selectedString
    @result String that represents the current selection.
*/
- (NSString *)selectedString;

/*!
    @method selectedAttributedString
    @result Attributed string that represents the current selection.
*/
- (NSAttributedString *)selectedAttributedString;


/*!
    @method selectAll
    @abstract Selects all the text in the document.
*/
- (void)selectAll;

/*!
    @method deselectText
    @abstract Causes a text selection to lose its selection.
*/
- (void)deselectAll;

@end


/*!
    @protocol WebDocumentRepresentation
    @discussion Protocol implemented by the document representation of a data source.
*/
@protocol WebDocumentRepresentation <NSObject>
/*!
    @method setDataSource:
    @abstract Called soon after the document representation is created.
    @param dataSource The data source that is set.
*/
- (void)setDataSource:(WebDataSource *)dataSource;

/*!
    @method receivedData:withDataSource:
    @abstract Called when the data source has received data.
    @param data The data that the data source has received.
    @param dataSource The data source that has received data.
*/
- (void)receivedData:(NSData *)data withDataSource:(WebDataSource *)dataSource;

/*!
    @method receivedError:withDataSource:
    @abstract Called when the data source has received an error.
    @param error The error that the data source has received.
    @param dataSource The data source that has received the error.
*/
- (void)receivedError:(NSError *)error withDataSource:(WebDataSource *)dataSource;

/*!
    @method finishedLoadingWithDataSource:
    @abstract Called when the data source has finished loading.
    @param dataSource The datasource that has finished loading.
*/
- (void)finishedLoadingWithDataSource:(WebDataSource *)dataSource;

/*!
    @method canProvideDocumentSource
    @result Returns true if the representation can provide document source.
*/
- (BOOL)canProvideDocumentSource;

/*!
    @method documentSource
    @result Returns the textual source representation of the document.  For HTML documents
    this is the original HTML source.
*/
- (NSString *)documentSource;

/*!
    @method title
    @result Return the title for the document.
*/
- (NSString *)title;

@end
