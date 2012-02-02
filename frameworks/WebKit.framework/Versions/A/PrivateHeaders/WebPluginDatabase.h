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

#import <Foundation/Foundation.h>

@class WebBasePluginPackage;
@class WebFrame;

@interface WebPluginDatabase : NSObject
{
    NSMutableDictionary *plugins;
    NSMutableSet *registeredMIMETypes;
    NSArray *plugInPaths;
    
    // Set of views with plugins attached
    NSMutableSet *pluginInstanceViews;
}

+ (WebPluginDatabase *)sharedDatabase;
+ (void)closeSharedDatabase; // avoids creating the database just to close it

// Plug-ins are returned in this order: New plug-in (WBPL), Mach-O Netscape, CFM Netscape
- (WebBasePluginPackage *)pluginForMIMEType:(NSString *)mimeType;
- (WebBasePluginPackage *)pluginForExtension:(NSString *)extension;

- (BOOL)isMIMETypeRegistered:(NSString *)MIMEType;

- (NSArray *)plugins;

- (void)refresh;

- (void)setPlugInPaths:(NSArray *)newPaths;

- (void)close;

- (void)addPluginInstanceView:(NSView *)view;
- (void)removePluginInstanceView:(NSView *)view;
- (void)removePluginInstanceViewsFor:(WebFrame *)webFrame;
- (void)destroyAllPluginInstanceViews;
@end

@interface NSObject (WebPlugInDatabase)

+ (void)setAdditionalWebPlugInPaths:(NSArray *)path;

@end
