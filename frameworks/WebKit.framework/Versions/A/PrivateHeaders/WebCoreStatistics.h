/*
 * Copyright (C) 2005, 2006 Apple Computer, Inc.  All rights reserved.
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

#import <Foundation/Foundation.h>

#import <WebKit/WebFrame.h>

@class DOMElement;

@interface WebCoreStatistics : NSObject
{
}

+ (NSArray *)statistics;

+ (size_t)javaScriptObjectsCount;
+ (size_t)javaScriptGlobalObjectsCount;
+ (size_t)javaScriptProtectedObjectsCount;
+ (size_t)javaScriptProtectedGlobalObjectsCount;
+ (NSCountedSet *)javaScriptProtectedObjectTypeCounts;
+ (NSCountedSet *)javaScriptObjectTypeCounts;

+ (void)garbageCollectJavaScriptObjects;
+ (void)garbageCollectJavaScriptObjectsOnAlternateThreadForDebugging:(BOOL)waitUntilDone;

+ (size_t)iconPageURLMappingCount;
+ (size_t)iconRetainedPageURLCount;
+ (size_t)iconRecordCount;
+ (size_t)iconsWithDataCount;

+ (size_t)cachedFontDataCount;
+ (size_t)cachedFontDataInactiveCount;
+ (void)purgeInactiveFontData;
+ (size_t)glyphPageCount;

+ (BOOL)shouldPrintExceptions;
+ (void)setShouldPrintExceptions:(BOOL)print;

+ (void)startIgnoringWebCoreNodeLeaks;
+ (void)stopIgnoringWebCoreNodeLeaks;

+ (NSDictionary *)memoryStatistics;
+ (void)returnFreeMemoryToSystem;

+ (int)cachedPageCount;
+ (int)cachedFrameCount;
+ (int)autoreleasedPageCount;

// Deprecated, but used by older versions of Safari.
+ (void)emptyCache;
+ (void)setCacheDisabled:(BOOL)disabled;
+ (size_t)javaScriptNoGCAllowedObjectsCount;
+ (size_t)javaScriptReferencedObjectsCount;
+ (NSSet *)javaScriptRootObjectClasses;
+ (NSCountedSet *)javaScriptRootObjectTypeCounts;
+ (size_t)javaScriptInterpretersCount;

@end

@interface WebFrame (WebKitDebug)
- (NSString *)renderTreeAsExternalRepresentationForPrinting:(BOOL)forPrinting;
- (NSString *)counterValueForElement:(DOMElement*)element;
- (int)pageNumberForElement:(DOMElement*)element:(float)pageWidthInPixels:(float)pageHeightInPixels;
- (int)numberOfPages:(float)pageWidthInPixels:(float)pageHeightInPixels;
- (NSString *)pageProperty:(const char*)propertyName:(int)pageNumber;
- (bool)isPageBoxVisible:(int)pageNumber;
- (NSString *)pageSizeAndMarginsInPixels:(int)pageNumber:(int)width:(int)height:(int)marginTop:(int)marginRight:(int)marginBottom:(int)marginLeft;
- (void)printToCGContext:(CGContextRef)cgContext:(float)pageWidthInPixels:(float)pageHeightInPixels;
@end
