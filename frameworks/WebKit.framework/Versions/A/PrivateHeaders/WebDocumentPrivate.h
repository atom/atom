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

#import <WebKit/WebDocument.h>
#import <WebKit/WebHTMLView.h>

@class DOMDocument;
@class PDFDocument;

@protocol WebDocumentImage <NSObject>
- (NSImage *)image;
@end

// This method is deprecated as it now lives on WebFrame.
@protocol WebDocumentDOM <NSObject>
- (DOMDocument *)DOMDocument;
- (BOOL)canSaveAsWebArchive;
@end

@protocol WebDocumentSelection <WebDocumentText>
- (NSArray *)pasteboardTypesForSelection;
- (void)writeSelectionWithPasteboardTypes:(NSArray *)types toPasteboard:(NSPasteboard *)pasteboard;

// Array of rects that tightly enclose the selected text, in coordinates of selectinView.
- (NSArray *)selectionTextRects;

// Rect tightly enclosing the entire selected area, in coordinates of selectionView.
- (NSRect)selectionRect;

// NSImage of the portion of the selection that's in view. This does not draw backgrounds. 
// The text is all black according to the parameter.
- (NSImage *)selectionImageForcingBlackText:(BOOL)forceBlackText;

// Rect tightly enclosing the entire selected area, in coordinates of selectionView.
// NOTE: This method is equivalent to selectionRect and shouldn't be used; use selectionRect instead.
- (NSRect)selectionImageRect;

// View that draws the selection and can be made first responder. Often this is self but it could be
// a nested view, as for example in the case of WebPDFView.
- (NSView *)selectionView;
@end

@protocol WebDocumentPDF <WebDocumentText>
- (PDFDocument *)PDFDocument;
@end

@protocol WebDocumentIncrementalSearching
/*!
@method searchFor:direction:caseSensitive:wrap:startInSelection:
 @abstract Searches a document view for a string and highlights the string if it is found.
 @param string The string to search for.
 @param forward YES to search forward, NO to seach backwards.
 @param caseFlag YES to for case-sensitive search, NO for case-insensitive search.
 @param wrapFlag YES to wrap around, NO to avoid wrapping.
 @param startInSelection YES to begin search in the selected text (useful for incremental searching), NO to begin search after the selected text.
 @result YES if found, NO if not found.
 */
- (BOOL)searchFor:(NSString *)string direction:(BOOL)forward caseSensitive:(BOOL)caseFlag wrap:(BOOL)wrapFlag startInSelection:(BOOL)startInSelection;
@end

@interface WebHTMLView (WebDocumentPrivateProtocols) <WebDocumentSelection, WebDocumentIncrementalSearching>
@end
