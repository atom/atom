/*
 * Copyright (C) 2003 Apple Computer, Inc.  All rights reserved.
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

@class WebHistoryItem;
@class WebBackForwardListPrivate;

/*!
    @class WebBackForwardList
    WebBackForwardList holds an ordered list of WebHistoryItems that comprises the back and
    forward lists.
    
    Note that the methods which modify instances of this class do not cause
    navigation to happen in other layers of the stack;  they are only for maintaining this data
    structure.
*/
@interface WebBackForwardList : NSObject {
@private
    WebBackForwardListPrivate *_private;
}

/*!
    @method addItem:
    @abstract Adds an entry to the list.
    @param entry The entry to add.
    @discussion The added entry is inserted immediately after the current entry.
    If the current position in the list is not at the end of the list, elements in the
    forward list will be dropped at this point.  In addition, entries may be dropped to keep
    the size of the list within the maximum size.
*/    
- (void)addItem:(WebHistoryItem *)item;

/*!
    @method goBack
    @abstract Move the current pointer back to the entry before the current entry.
*/
- (void)goBack;

/*!
    @method goForward
    @abstract Move the current pointer ahead to the entry after the current entry.
*/
- (void)goForward;

/*!
    @method goToItem:
    @abstract Move the current pointer to the given entry.
    @param item The history item to move the pointer to
*/
- (void)goToItem:(WebHistoryItem *)item;

/*!
    @method backItem
    @abstract Returns the entry right before the current entry.
    @result The entry right before the current entry, or nil if there isn't one.
*/
- (WebHistoryItem *)backItem;

/*!
    @method currentItem
    @abstract Returns the current entry.
    @result The current entry.
*/
- (WebHistoryItem *)currentItem;

/*!
    @method forwardItem
    @abstract Returns the entry right after the current entry.
    @result The entry right after the current entry, or nil if there isn't one.
*/
- (WebHistoryItem *)forwardItem;

/*!
    @method backListWithLimit:
    @abstract Returns a portion of the list before the current entry.
    @param limit A cap on the size of the array returned.
    @result An array of items before the current entry, or nil if there are none.  The entries are in the order that they were originally visited.
*/
- (NSArray *)backListWithLimit:(int)limit;

/*!
    @method forwardListWithLimit:
    @abstract Returns a portion of the list after the current entry.
    @param limit A cap on the size of the array returned.
    @result An array of items after the current entry, or nil if there are none.  The entries are in the order that they were originally visited.
*/
- (NSArray *)forwardListWithLimit:(int)limit;

/*!
    @method capacity
    @abstract Returns the list's maximum size.
    @result The list's maximum size.
*/
- (int)capacity;

/*!
    @method setCapacity
    @abstract Sets the list's maximum size.
    @param size The new maximum size for the list.
*/
- (void)setCapacity:(int)size;

/*!
    @method backListCount
    @abstract Returns the back list's current count.
    @result The number of items in the list.
*/
- (int)backListCount;

/*!
    @method forwardListCount
    @abstract Returns the forward list's current count.
    @result The number of items in the list.
*/
- (int)forwardListCount;

/*!
    @method containsItem:
    @param item The item that will be checked for presence in the WebBackForwardList.
    @result Returns YES if the item is in the list. 
*/
- (BOOL)containsItem:(WebHistoryItem *)item;

/*!
    @method itemAtIndex:
    @abstract Returns an entry the given distance from the current entry.
    @param index Index of the desired list item relative to the current item; 0 is current item, -1 is back item, 1 is forward item, etc.
    @result The entry the given distance from the current entry. If index exceeds the limits of the list, nil is returned.
*/
- (WebHistoryItem *)itemAtIndex:(int)index;

@end

@interface WebBackForwardList(WebBackForwardListDeprecated)

// The following methods are deprecated, and exist for backward compatibility only.
// Use -[WebPreferences setUsesPageCache] and -[WebPreferences usesPageCache]
// instead.

/*!
    @method setPageCacheSize:
    @abstract The size passed to this method determines whether the WebView 
    associated with this WebBackForwardList will use the shared page cache.
    @param size If size is 0, the WebView associated with this WebBackForwardList
    will not use the shared page cache. Otherwise, it will.
*/
- (void)setPageCacheSize:(NSUInteger)size;

/*!
    @method pageCacheSize
    @abstract Returns the size of the shared page cache, or 0.
    @result The size of the shared page cache (in pages), or 0 if the WebView 
    associated with this WebBackForwardList will not use the shared page cache.
*/
- (NSUInteger)pageCacheSize;
@end
