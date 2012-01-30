/*
 * Copyright (C) 2004, 2005 Apple Computer, Inc.  All rights reserved.
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

#import <WebKit/DOMCore.h>
#import <WebKit/DOMHTML.h>
#import <WebKit/DOMRange.h>

@class WebArchive;
@class WebFrame;

@interface DOMNode (WebDOMNodeOperations)

/*!
    @method webArchive
    @result A WebArchive representing the node and the children of the node.
*/
- (WebArchive *)webArchive;

@end

@interface DOMDocument (WebDOMDocumentOperations)

/*!
    @method webFrame
    @abstract Returns the frame of the DOM document.
*/
- (WebFrame *)webFrame;

/*!
    @method URLWithAttributeString:
    @abstract Constructs a URL given an attribute string.
    @discussion This method constructs a URL given an attribute string just as WebKit does. 
    An attribute string is the value of an attribute of an element such as the href attribute on 
    the DOMHTMLAnchorElement class. This method is only applicable to attributes that refer to URLs.
*/
- (NSURL *)URLWithAttributeString:(NSString *)string;

@end

@interface DOMRange (WebDOMRangeOperations)

/*!
    @method webArchive
    @result A WebArchive representing the range.
*/
- (WebArchive *)webArchive;

/*!
    @method markupString
    @result A markup string representing the range.
*/
- (NSString *)markupString;

@end

@interface DOMHTMLFrameElement (WebDOMHTMLFrameElementOperations)

/*!
    @method contentFrame
    @abstract Returns the content frame of the element.
*/
- (WebFrame *)contentFrame;

@end

@interface DOMHTMLIFrameElement (WebDOMHTMLIFrameElementOperations)

/*!
    @method contentFrame
    @abstract Returns the content frame of the element.
*/
- (WebFrame *)contentFrame;

@end

@interface DOMHTMLObjectElement (WebDOMHTMLObjectElementOperations)

/*!
    @method contentFrame
    @abstract Returns the content frame of the element.
    @discussion Returns non-nil only if the object represents a child frame
    such as if the data of the object is HTML content.
*/
- (WebFrame *)contentFrame;

@end
