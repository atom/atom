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

// Sent whenever a site icon has changed. The object of the notification is the icon database.
// The userInfo contains the site URL whose icon has changed.
// It can be accessed with the key WebIconNotificationUserInfoURLKey.
extern NSString *WebIconDatabaseDidAddIconNotification;

extern NSString *WebIconNotificationUserInfoURLKey;

extern NSString *WebIconDatabaseDirectoryDefaultsKey;
extern NSString *WebIconDatabaseEnabledDefaultsKey;

extern NSSize WebIconSmallSize;  // 16 x 16
extern NSSize WebIconMediumSize; // 32 x 32
extern NSSize WebIconLargeSize;  // 128 x 128

@class WebIconDatabasePrivate;

/*!
    @class WebIconDatabase
    @discussion Features:
        - memory cache icons at different sizes
        - disk storage
        - icon update notification
        
        Uses:
        - UI elements to retrieve icons that represent site URLs.
        - Save icons to disk for later use.
 
    Every icon in the database has a retain count.  If an icon has a retain count greater than 0, it will be written to disk for later use. If an icon's retain count equals zero it will be removed from disk.  The retain count is not persistent across launches. If the WebKit client wishes to retain an icon it should retain the icon once for every launch.  This is best done at initialization time before the database begins removing icons.  To make sure that the database does not remove unretained icons prematurely, call delayDatabaseCleanup until all desired icons are retained.  Once all are retained, call allowDatabaseCleanup.
    
    Note that an icon can be retained after the database clean-up has begun. This just has to be done before the icon is removed. Icons are removed from the database whenever new icons are added to it.
    
    Retention methods can be called for icons that are not yet in the database.
*/
@interface WebIconDatabase : NSObject {

@private
    WebIconDatabasePrivate *_private;
    BOOL _isClosing;
}


/*!
    @method sharedIconDatabase
    @abstract Returns a shared instance of the icon database
*/
+ (WebIconDatabase *)sharedIconDatabase;

/*!
    @method iconForURL:withSize:
    @discussion Calls iconForURL:withSize:cache: with YES for cache.
    @param URL
    @param size
*/
- (NSImage *)iconForURL:(NSString *)URL withSize:(NSSize)size;

/*!
    @method iconForURL:withSize:cache:
    @discussion Returns an icon for a web site URL from memory or disk. nil if none is found.
    Usually called by a UI element to determine if a site URL has an associated icon.
    Often called by the observer of WebIconChangedNotification after the notification is sent.
    @param URL
    @param size
    @param cache If yes, caches the returned image in memory if not already cached
*/
- (NSImage *)iconForURL:(NSString *)URL withSize:(NSSize)size cache:(BOOL)cache;

/*!
    @method iconURLForURL:withSize:cache:
    @discussion Returns an icon URL for a web site URL from memory or disk. nil if none is found.
    @param URL
*/
- (NSString *)iconURLForURL:(NSString *)URL;

/*!
    @method defaultIconWithSize:
    @param size
*/
- (NSImage *)defaultIconWithSize:(NSSize)size;
- (NSImage *)defaultIconForURL:(NSString *)URL withSize:(NSSize)size;

/*!
    @method retainIconForURL:
    @abstract Increments the retain count of the icon.
    @param URL
*/
- (void)retainIconForURL:(NSString *)URL;

/*!
    @method releaseIconForURL:
    @abstract Decrements the retain count of the icon.
    @param URL
*/
- (void)releaseIconForURL:(NSString *)URL;

/*!
    @method delayDatabaseCleanup:
    @discussion Only effective if called before the database begins removing icons.
    delayDatabaseCleanUp increments an internal counter that when 0 begins the database clean-up.
    The counter equals 0 at initialization.
*/
+ (void)delayDatabaseCleanup;

/*!
    @method allowDatabaseCleanup:
    @discussion Informs the database that it now can begin removing icons.
    allowDatabaseCleanup decrements an internal counter that when 0 begins the database clean-up.
    The counter equals 0 at initialization.
*/
+ (void)allowDatabaseCleanup;

- (void)setDelegate:(id)delegate;
- (id)delegate;

@end


