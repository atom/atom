/*
 * Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011 Apple Inc. All rights reserved.
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

// This header contains the WebFrame SPI.

#import <WebKit/WebFrame.h>
#import <JavaScriptCore/JSBase.h>

#if !defined(ENABLE_NETSCAPE_PLUGIN_API)
#define ENABLE_NETSCAPE_PLUGIN_API 1
#endif

@class DOMDocumentFragment;
@class DOMNode;
@class DOMRange;
@class WebScriptObject;
@class WebScriptWorld;

// Keys for accessing the values in the page cache dictionary.
extern NSString *WebPageCacheEntryDateKey;
extern NSString *WebPageCacheDataSourceKey;
extern NSString *WebPageCacheDocumentViewKey;

extern NSString *WebFrameMainDocumentError;
extern NSString *WebFrameHasPlugins;
extern NSString *WebFrameHasUnloadListener;
extern NSString *WebFrameUsesDatabases;
extern NSString *WebFrameUsesGeolocation;
extern NSString *WebFrameUsesApplicationCache;
extern NSString *WebFrameCanSuspendActiveDOMObjects;

typedef enum {
    WebFrameLoadTypeStandard,
    WebFrameLoadTypeBack,
    WebFrameLoadTypeForward,
    WebFrameLoadTypeIndexedBackForward, // a multi-item hop in the backforward list
    WebFrameLoadTypeReload,
    WebFrameLoadTypeReloadAllowingStaleData,
    WebFrameLoadTypeSame,               // user loads same URL again (but not reload button)
    WebFrameLoadTypeInternal,           // maps to WebCore::FrameLoadTypeRedirectWithLockedBackForwardList
    WebFrameLoadTypeReplace,
    WebFrameLoadTypeReloadFromOrigin,
} WebFrameLoadType;

@interface WebFrame (WebPrivate)

- (BOOL)_isDescendantOfFrame:(WebFrame *)frame;
- (void)_setShouldCreateRenderers:(BOOL)shouldCreateRenderers;
- (NSColor *)_bodyBackgroundColor;
- (BOOL)_isFrameSet;
- (BOOL)_firstLayoutDone;
- (BOOL)_isVisuallyNonEmpty;
- (WebFrameLoadType)_loadType;

// These methods take and return NSRanges based on the root editable element as the positional base.
// This fits with AppKit's idea of an input context. These methods are slow compared to their DOMRange equivalents.
// You should use WebView's selectedDOMRange and setSelectedDOMRange whenever possible.
- (NSRange)_selectedNSRange;
- (void)_selectNSRange:(NSRange)range;

- (BOOL)_isDisplayingStandaloneImage;

- (unsigned)_pendingFrameUnloadEventCount;

- (void)_setIsDisconnected:(bool)isDisconnected;
- (void)_setExcludeFromTextSearch:(bool)exclude;

#if ENABLE_NETSCAPE_PLUGIN_API
- (void)_recursive_resumeNullEventsForAllNetscapePlugins;
- (void)_recursive_pauseNullEventsForAllNetscapePlugins;
#endif

- (NSString *)_stringByEvaluatingJavaScriptFromString:(NSString *)string withGlobalObject:(JSObjectRef)globalObject inScriptWorld:(WebScriptWorld *)world;
- (JSGlobalContextRef)_globalContextForScriptWorld:(WebScriptWorld *)world;

// Pause a given CSS animation or transition on the target node at a specific time.
// If the animation or transition is already paused, it will update its pause time.
// This method is only intended to be used for testing the CSS animation and transition system.
- (BOOL)_pauseAnimation:(NSString*)name onNode:(DOMNode *)node atTime:(NSTimeInterval)time;
- (BOOL)_pauseTransitionOfProperty:(NSString*)name onNode:(DOMNode*)node atTime:(NSTimeInterval)time;

// Pause a given SVG animation on the target node at a specific time.
// This method is only intended to be used for testing the SVG animation system.
- (BOOL)_pauseSVGAnimation:(NSString*)elementId onSMILNode:(DOMNode *)node atTime:(NSTimeInterval)time;

// Returns the total number of currently running animations (includes both CSS transitions and CSS animations).
- (unsigned)_numberOfActiveAnimations;

// Suspend and resume animations (includes both CSS transitions and CSS animations).
- (void)_suspendAnimations;
- (void)_resumeAnimations;

- (void)_replaceSelectionWithFragment:(DOMDocumentFragment *)fragment selectReplacement:(BOOL)selectReplacement smartReplace:(BOOL)smartReplace matchStyle:(BOOL)matchStyle;
- (void)_replaceSelectionWithText:(NSString *)text selectReplacement:(BOOL)selectReplacement smartReplace:(BOOL)smartReplace;
- (void)_replaceSelectionWithMarkupString:(NSString *)markupString baseURLString:(NSString *)baseURLString selectReplacement:(BOOL)selectReplacement smartReplace:(BOOL)smartReplace;

- (void)_smartInsertForString:(NSString *)pasteString replacingRange:(DOMRange *)rangeToReplace beforeString:(NSString **)beforeString afterString:(NSString **)afterString;

- (NSMutableDictionary *)_cacheabilityDictionary;

- (BOOL)_allowsFollowingLink:(NSURL *)URL;

// Sets whether the scrollbars, if any, should be shown inside the document's border 
// (thus overlapping some content) or outside the webView's border (default behavior). 
// Changing this flag changes the size of the contentView and maintains the size of the frameView.
- (void)setAllowsScrollersToOverlapContent:(BOOL)flag;

// Sets if the scrollbar is always hidden, regardless of other scrollbar visibility settings. 
// This does not affect the scrollability of the document.
- (void)setAlwaysHideHorizontalScroller:(BOOL)flag;
- (void)setAlwaysHideVerticalScroller:(BOOL)flag;

// Sets the name presented to accessibility clients for the web area object.
- (void)setAccessibleName:(NSString *)name;

- (NSString*)_layerTreeAsText;

// Returns whether there is a spelling marker in the specified range of the focused node.
- (BOOL)hasSpellingMarker:(int)location length:(int)length;

- (BOOL)hasGrammarMarker:(int)from length:(int)length;

// The top of the accessibility tree.
- (id)accessibilityRoot;

// Clears frame opener. This is executed between layout tests runs
- (void)_clearOpener;

// Printing.
- (NSArray *)_computePageRectsWithPrintScaleFactor:(float)printWidthScaleFactor pageSize:(NSSize)pageSize;

@end
