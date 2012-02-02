/*
 * Copyright (C) 2005, 2008, 2009 Apple Inc. All rights reserved.
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

#import <WebKit/WebHistory.h>

/*
    @constant WebHistoryItemsDiscardedWhileLoadingNotification Posted from loadFromURL:error:.  
    This notification comes with a userInfo dictionary that contains the array of
    items discarded due to the date limit or item limit. The key for the array is WebHistoryItemsKey.
*/
// FIXME: This notification should become public API.
extern NSString *WebHistoryItemsDiscardedWhileLoadingNotification;

@interface WebHistory (WebPrivate)

// FIXME: The following SPI is used by Safari. Should it be made into public API?
- (WebHistoryItem *)_itemForURLString:(NSString *)URLString;

/*!
    @method allItems
    @result Returns an array of all WebHistoryItems in WebHistory, in an undefined order.
*/
- (NSArray *)allItems;

/*!
    @method _data
    @result A data object with the entire history in the same format used by the saveToURL:error: method.
*/
- (NSData *)_data;

+ (void)_setVisitedLinkTrackingEnabled:(BOOL)visitedLinkTrackingEnabled;
+ (void)_removeAllVisitedLinks;
@end
