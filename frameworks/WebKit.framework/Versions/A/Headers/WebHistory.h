/*
 * Copyright (C) 2003, 2004 Apple Computer, Inc.  All rights reserved.
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

@class NSError;

@class WebHistoryItem;
@class WebHistoryPrivate;

/*
    @discussion Notifications sent when history is modified. 
    @constant WebHistoryItemsAddedNotification Posted from addItems:.  This 
    notification comes with a userInfo dictionary that contains the array of
    items added.  The key for the array is WebHistoryItemsKey.
    @constant WebHistoryItemsRemovedNotification Posted from removeItems:.  
    This notification comes with a userInfo dictionary that contains the array of
    items removed.  The key for the array is WebHistoryItemsKey.
    @constant WebHistoryAllItemsRemovedNotification Posted from removeAllItems
    @constant WebHistoryLoadedNotification Posted from loadFromURL:error:.
*/
extern NSString *WebHistoryItemsAddedNotification;
extern NSString *WebHistoryItemsRemovedNotification;
extern NSString *WebHistoryAllItemsRemovedNotification;
extern NSString *WebHistoryLoadedNotification;
extern NSString *WebHistorySavedNotification;

extern NSString *WebHistoryItemsKey;

/*!
    @class WebHistory
    @discussion WebHistory is used to track pages that have been loaded
    by WebKit.
*/
@interface WebHistory : NSObject {
@private
    WebHistoryPrivate *_historyPrivate;
}

/*!
    @method optionalSharedHistory
    @abstract Returns a shared WebHistory instance initialized with the default history file.
    @result A WebHistory object.
*/
+ (WebHistory *)optionalSharedHistory;

/*!
    @method setOptionalSharedHistory:
    @param history The history to use for the global WebHistory.
*/
+ (void)setOptionalSharedHistory:(WebHistory *)history;

/*!
    @method loadFromURL:error:
    @param URL The URL to use to initialize the WebHistory.
    @param error Set to nil or an NSError instance if an error occurred.
    @abstract The designated initializer for WebHistory.
    @result Returns YES if successful, NO otherwise.
*/
- (BOOL)loadFromURL:(NSURL *)URL error:(NSError **)error;

/*!
    @method saveToURL:error:
    @discussion Save history to URL. It is the client's responsibility to call this at appropriate times.
    @param URL The URL to use to save the WebHistory.
    @param error Set to nil or an NSError instance if an error occurred.
    @result Returns YES if successful, NO otherwise.
*/
- (BOOL)saveToURL:(NSURL *)URL error:(NSError **)error;

/*!
    @method addItems:
    @param newItems An array of WebHistoryItems to add to the WebHistory.
*/
- (void)addItems:(NSArray *)newItems;

/*!
    @method removeItems:
    @param items An array of WebHistoryItems to remove from the WebHistory.
*/
- (void)removeItems:(NSArray *)items;

/*!
    @method removeAllItems
*/
- (void)removeAllItems;

/*!
    @method orderedLastVisitedDays
    @discussion Get an array of NSCalendarDates, each one representing a unique day that contains one
    or more history items, ordered from most recent to oldest.
    @result Returns an array of NSCalendarDates for which history items exist in the WebHistory.
*/
- (NSArray *)orderedLastVisitedDays;

/*!
    @method orderedItemsLastVisitedOnDay:
    @discussion Get an array of WebHistoryItem that were last visited on the day represented by the
    specified NSCalendarDate, ordered from most recent to oldest.
    @param calendarDate A date identifying the unique day of interest.
    @result Returns an array of WebHistoryItems last visited on the indicated day.
*/
- (NSArray *)orderedItemsLastVisitedOnDay:(NSCalendarDate *)calendarDate;

/*!
    @method itemForURL:
    @abstract Get an item for a specific URL
    @param URL The URL of the history item to search for
    @result Returns an item matching the URL
*/
- (WebHistoryItem *)itemForURL:(NSURL *)URL;

/*!
    @method setHistoryItemLimit:
    @discussion Limits the number of items that will be stored by the WebHistory.
    @param limit The maximum number of items that will be stored by the WebHistory.
*/
- (void)setHistoryItemLimit:(int)limit;

/*!
    @method historyItemLimit
    @result The maximum number of items that will be stored by the WebHistory.
*/
- (int)historyItemLimit;

/*!
    @method setHistoryAgeInDaysLimit:
    @discussion setHistoryAgeInDaysLimit: sets the maximum number of days to be read from
    stored history.
    @param limit The maximum number of days to be read from stored history.
*/
- (void)setHistoryAgeInDaysLimit:(int)limit;

/*!
    @method historyAgeInDaysLimit
    @return Returns the maximum number of days to be read from stored history.
*/
- (int)historyAgeInDaysLimit;

@end
