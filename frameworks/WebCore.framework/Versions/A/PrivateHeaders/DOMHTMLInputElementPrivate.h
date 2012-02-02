/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Samuel Weinig <sam.weinig@gmail.com>
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import <WebCore/DOMHTMLInputElement.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_1_3

@class DOMHTMLElement;
@class DOMHTMLOptionElement;
@class DOMNodeList;
@class DOMValidityState;
@protocol DOMEventListener;

@interface DOMHTMLInputElement (DOMHTMLInputElementPrivate)
@property(copy) NSString *dirName;
@property(copy) NSString *formAction;
@property(copy) NSString *formEnctype;
@property(copy) NSString *formMethod;
@property BOOL formNoValidate;
@property(copy) NSString *formTarget;
@property(readonly, retain) DOMValidityState *validity;
@property(copy) NSString *autocomplete;
@property(readonly, retain) DOMHTMLElement *list;
@property(copy) NSString *max;
@property(copy) NSString *min;
@property BOOL webkitdirectory;
@property(copy) NSString *pattern;
@property(copy) NSString *placeholder;
@property BOOL required;
@property(copy) NSString *step;
@property NSTimeInterval valueAsDate;
@property double valueAsNumber;
@property(readonly, retain) DOMHTMLOptionElement *selectedOption;
@property BOOL incremental;
@property(readonly, copy) NSString *validationMessage;
@property(copy) NSString *selectionDirection;
@property(readonly, retain) DOMNodeList *labels;
@property BOOL webkitSpeech;
@property BOOL webkitGrammar;
@property(retain) id <DOMEventListener> onwebkitspeechchange;

- (void)stepUp:(int)n;
- (void)stepDown:(int)n;
- (BOOL)checkValidity;
- (void)setCustomValidity:(NSString *)error;
- (void)setValueForUser:(NSString *)value;
@end

#endif
