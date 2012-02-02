/*
 * Copyright (C) 2005, 2006, 2008 Apple Inc. All rights reserved.
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

#import <WebKit/WebHistoryItem.h>

@interface WebHistoryItem (WebPrivate)

+ (void)_releaseAllPendingPageCaches;

- (id)initWithURL:(NSURL *)URL title:(NSString *)title;

- (NSURL *)URL;
- (int)visitCount;
- (BOOL)lastVisitWasFailure;
- (void)_setLastVisitWasFailure:(BOOL)failure;

- (BOOL)_lastVisitWasHTTPNonGet;

- (NSString *)RSSFeedReferrer;
- (void)setRSSFeedReferrer:(NSString *)referrer;
- (NSCalendarDate *)_lastVisitedDate;

- (NSArray *)_redirectURLs;

- (WebHistoryItem *)targetItem;
- (NSString *)target;
- (BOOL)isTargetItem;
- (NSArray *)children;
- (NSDictionary *)dictionaryRepresentation;

// This should not be called directly for WebHistoryItems that are already included
// in WebHistory. Use -[WebHistory setLastVisitedTimeInterval:forItem:] instead.
- (void)_setLastVisitedTimeInterval:(NSTimeInterval)time;
// Transient properties may be of any ObjC type.  They are intended to be used to store state per back/forward list entry.
// The properties will not be persisted; when the history item is removed, the properties will be lost.
- (id)_transientPropertyForKey:(NSString *)key;
- (void)_setTransientProperty:(id)property forKey:(NSString *)key;

- (size_t)_getDailyVisitCounts:(const int**)counts;
- (size_t)_getWeeklyVisitCounts:(const int**)counts;

@end
