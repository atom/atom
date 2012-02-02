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

#import <WebKit/DOMCSSValue.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_1_3

@class DOMCounter;
@class DOMRGBColor;
@class DOMRect;
@class NSString;

enum {
    DOM_CSS_UNKNOWN = 0,
    DOM_CSS_NUMBER = 1,
    DOM_CSS_PERCENTAGE = 2,
    DOM_CSS_EMS = 3,
    DOM_CSS_EXS = 4,
    DOM_CSS_PX = 5,
    DOM_CSS_CM = 6,
    DOM_CSS_MM = 7,
    DOM_CSS_IN = 8,
    DOM_CSS_PT = 9,
    DOM_CSS_PC = 10,
    DOM_CSS_DEG = 11,
    DOM_CSS_RAD = 12,
    DOM_CSS_GRAD = 13,
    DOM_CSS_MS = 14,
    DOM_CSS_S = 15,
    DOM_CSS_HZ = 16,
    DOM_CSS_KHZ = 17,
    DOM_CSS_DIMENSION = 18,
    DOM_CSS_STRING = 19,
    DOM_CSS_URI = 20,
    DOM_CSS_IDENT = 21,
    DOM_CSS_ATTR = 22,
    DOM_CSS_COUNTER = 23,
    DOM_CSS_RECT = 24,
    DOM_CSS_RGBCOLOR = 25
};

@interface DOMCSSPrimitiveValue : DOMCSSValue
@property(readonly) unsigned short primitiveType;

- (void)setFloatValue:(unsigned short)unitType floatValue:(float)floatValue AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (float)getFloatValue:(unsigned short)unitType;
- (void)setStringValue:(unsigned short)stringType stringValue:(NSString *)stringValue AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (NSString *)getStringValue;
- (DOMCounter *)getCounterValue;
- (DOMRect *)getRectValue;
- (DOMRGBColor *)getRGBColorValue;
@end

@interface DOMCSSPrimitiveValue (DOMCSSPrimitiveValueDeprecated)
- (void)setFloatValue:(unsigned short)unitType :(float)floatValue AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (void)setStringValue:(unsigned short)stringType :(NSString *)stringValue AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
@end

#endif
