/*
 * Copyright (C) 2007, 2008 Apple Inc. All rights reserved.
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

#if ENABLE(SQL_DATABASE)

extern NSString *WebDatabaseDirectoryDefaultsKey;

extern NSString *WebDatabaseDisplayNameKey;
extern NSString *WebDatabaseExpectedSizeKey;
extern NSString *WebDatabaseUsageKey;

// Posted with an origin is created from scratch, gets a new database, has a database deleted, has a quota change, etc
// The notification object will be a WebSecurityOrigin object corresponding to the origin.
extern NSString *WebDatabaseDidModifyOriginNotification;

// Posted when a database is created, its size increases, its display name changes, or its estimated size changes, or the database is removed
// The notification object will be a WebSecurityOrigin object corresponding to the origin.
// The notification userInfo will have a WebDatabaseNameKey whose value is the database name.
extern NSString *WebDatabaseDidModifyDatabaseNotification;
extern NSString *WebDatabaseIdentifierKey;

@class WebSecurityOrigin;

@interface WebDatabaseManager : NSObject

+ (WebDatabaseManager *)sharedWebDatabaseManager;

// Will return an array of WebSecurityOrigin objects.
- (NSArray *)origins;

// Will return an array of strings, the identifiers of each database in the given origin.
- (NSArray *)databasesWithOrigin:(WebSecurityOrigin *)origin;

// Will return the dictionary describing everything about the database for the passed identifier and origin.
- (NSDictionary *)detailsForDatabase:(NSString *)databaseIdentifier withOrigin:(WebSecurityOrigin *)origin;

- (void)deleteAllDatabases; // Deletes all databases and all origins.
- (BOOL)deleteOrigin:(WebSecurityOrigin *)origin;
- (BOOL)deleteDatabase:(NSString *)databaseIdentifier withOrigin:(WebSecurityOrigin *)origin;

@end

#endif
