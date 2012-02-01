/*
 * Copyright (C) 2004 Apple Computer, Inc.  All rights reserved.
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
#import <JavaScriptCore/WebKitAvailability.h>

/*!
    @constant WebPlugInBaseURLKey REQUIRED. The base URL of the document containing
    the plug-in's view.
*/
extern NSString *WebPlugInBaseURLKey;

/*!
    @constant WebPlugInAttributesKey REQUIRED. The dictionary containing the names
    and values of all attributes of the HTML element associated with the plug-in AND
    the names and values of all parameters to be passed to the plug-in (e.g. PARAM
    elements within an APPLET element). In the case of a conflict between names,
    the attributes of an element take precedence over any PARAMs.  All of the keys
    and values in this NSDictionary must be NSStrings.
*/
extern NSString *WebPlugInAttributesKey;

/*!
    @constant WebPlugInContainer OPTIONAL. An object that conforms to the
    WebPlugInContainer informal protocol. This object is used for
    callbacks from the plug-in to the app. if this argument is nil, no callbacks will
    occur.
*/
extern NSString *WebPlugInContainerKey;

/*!
    @constant WebPlugInContainingElementKey The DOMElement that was used to specify
    the plug-in.  May be nil.
*/
extern NSString *WebPlugInContainingElementKey;

/*!
 @constant WebPlugInShouldLoadMainResourceKey REQUIRED. NSNumber (BOOL) indicating whether the plug-in should load its
 own main resource (the "src" URL, in most cases). If YES, the plug-in should load its own main resource. If NO, the
 plug-in should use the data provided by WebKit. See -webPlugInMainResourceReceivedData: in WebPluginPrivate.h.
 For compatibility with older versions of WebKit, the plug-in should assume that the value for
 WebPlugInShouldLoadMainResourceKey is NO if it is absent from the arguments dictionary.
 */
extern NSString *WebPlugInShouldLoadMainResourceKey AVAILABLE_IN_WEBKIT_VERSION_4_0;

/*!
    @protocol WebPlugInViewFactory
    @discussion WebPlugInViewFactory are used to create the NSView for a plug-in.
    The principal class of the plug-in bundle must implement this protocol.
*/

@protocol WebPlugInViewFactory <NSObject>

/*!
    @method plugInViewWithArguments: 
    @param arguments The arguments dictionary with the mentioned keys and objects. This method is required to implement.
    @result Returns an NSView object that conforms to the WebPlugIn informal protocol.
*/
+ (NSView *)plugInViewWithArguments:(NSDictionary *)arguments;

@end
