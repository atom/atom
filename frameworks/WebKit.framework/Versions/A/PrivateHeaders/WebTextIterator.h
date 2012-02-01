/*
 * Copyright (C) 2008, 2009 Apple Inc. All Rights Reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import <Foundation/Foundation.h>

@class DOMRange;
@class DOMNode;
@class WebTextIteratorPrivate;

@interface WebTextIterator : NSObject {
@private
    WebTextIteratorPrivate *_private;
}

- (id)initWithRange:(DOMRange *)range;

/*!
 @method advance
 @abstract Moves the WebTextIterator to the next bit of text or boundary between runs of text.
 The iterator can break up runs of text however it finds convenient, so clients need to handle
 text runs that are broken up into arbitrary pieces.
 */
- (void)advance;

/*!
 @method atEnd
 @result YES if the WebTextIterator has reached the end of the DOMRange.
 */
- (BOOL)atEnd;

/*!
 @method currentTextLength
 @result Length of the current text. Length of zero means that the iterator is at a boundary,
 such as an image, that separates runs of text.
 */
- (NSUInteger)currentTextLength;

/*!
 @method currentTextPointer
 @result A pointer to the current text. Like the WebTextIterator itself, the pointer becomes
 invalid after any modification is made to the document; it must be used before the document
 is changed or the iterator is advanced.
 */
- (const unichar *)currentTextPointer;

/*!
 @method currentRange
 @abstract A function that identifies the specific document range that text corresponds to.
 This can be quite costly to compute for non-text items, so when possible this should only
 be called once the caller has determined that the text is text it wants to process. If you
 call currentRange every time you advance the iterator, performance will be extremely slow
 due to the cost of computing a DOM range.
 @result A DOM range indicating the position within the document of the current text.
 */
- (DOMRange *)currentRange;

@end

@interface WebTextIterator (WebTextIteratorDeprecated)

/*!
 @method currentNode
 @abstract A convenience method that finds the first node in currentRange; it's almost always better to use currentRange instead.
 @result The current DOMNode in the WebTextIterator
 */
- (DOMNode *)currentNode;

/*!
 @method currentText
 @abstract A convenience method that makes an NSString out of the current text; it's almost always better to use currentTextPointer and currentTextLength instead.
 @result The current text in the WebTextIterator.
 */
- (NSString *)currentText;

@end
