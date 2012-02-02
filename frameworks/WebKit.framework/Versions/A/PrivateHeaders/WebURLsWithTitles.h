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

#import <Cocoa/Cocoa.h>

#define WebURLsWithTitlesPboardType     @"WebURLsWithTitlesPboardType"

// Convenience class for getting URLs and associated titles on and off an NSPasteboard

@interface WebURLsWithTitles : NSObject

// Writes parallel arrays of URLs and titles to the pasteboard. These items can be retrieved by
// calling URLsFromPasteboard and titlesFromPasteboard. URLs must consist of NSURL objects.
// titles must consist of NSStrings, or be nil. If titles is nil, or if titles is a different
// length than URLs, empty strings will be used for all titles. If URLs is nil, this method
// returns without doing anything. You must declare an WebURLsWithTitlesPboardType data type
// for pasteboard before invoking this method, or it will return without doing anything.
+ (void)writeURLs:(NSArray *)URLs andTitles:(NSArray *)titles toPasteboard:(NSPasteboard *)pasteboard;

// Reads an array of NSURLs off the pasteboard. Returns nil if pasteboard does not contain
// data of type WebURLsWithTitlesPboardType. This array consists of the URLs that correspond to
// the titles returned from titlesFromPasteboard.
+ (NSArray *)URLsFromPasteboard:(NSPasteboard *)pasteboard;

// Reads an array of NSStrings off the pasteboard. Returns nil if pasteboard does not contain
// data of type WebURLsWithTitlesPboardType. This array consists of the titles that correspond to
// the URLs returned from URLsFromPasteboard.
+ (NSArray *)titlesFromPasteboard:(NSPasteboard *)pasteboard;

@end
