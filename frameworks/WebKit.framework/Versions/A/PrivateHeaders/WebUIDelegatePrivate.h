/*
 * Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#import <WebKit/WebUIDelegate.h>

#if !defined(ENABLE_DASHBOARD_SUPPORT)
#define ENABLE_DASHBOARD_SUPPORT 1
#endif

#if !defined(ENABLE_FULLSCREEN_API)
#define ENABLE_FULLSCREEN_API 1
#endif

// Mail on Tiger expects the old value for WebMenuItemTagSearchInGoogle
#define WebMenuItemTagSearchInGoogle OldWebMenuItemTagSearchWeb

#define WEBMENUITEMTAG_WEBKIT_3_0_SPI_START 2000
enum { 
    // The next three values were used in WebKit 2.0 for SPI. In WebKit 3.0 these are API, with different values.
    OldWebMenuItemTagSearchInSpotlight = 1000,
    OldWebMenuItemTagSearchWeb,
    OldWebMenuItemTagLookUpInDictionary,
    // FIXME: These should move to WebUIDelegate.h as part of the WebMenuItemTag enum there, when we're not in API freeze 
    // Note that these values must be kept aligned with values in WebCore/ContextMenuItem.h
    WebMenuItemTagOpenLink = WEBMENUITEMTAG_WEBKIT_3_0_SPI_START,
    WebMenuItemTagIgnoreGrammar,
    WebMenuItemTagSpellingMenu,
    WebMenuItemTagShowSpellingPanel,
    WebMenuItemTagCheckSpelling,
    WebMenuItemTagCheckSpellingWhileTyping,
    WebMenuItemTagCheckGrammarWithSpelling,
    WebMenuItemTagFontMenu,
    WebMenuItemTagShowFonts,
    WebMenuItemTagBold,
    WebMenuItemTagItalic,
    WebMenuItemTagUnderline,
    WebMenuItemTagOutline,
    WebMenuItemTagStyles,
    WebMenuItemTagShowColors,
    WebMenuItemTagSpeechMenu,
    WebMenuItemTagStartSpeaking,
    WebMenuItemTagStopSpeaking,
    WebMenuItemTagWritingDirectionMenu,
    WebMenuItemTagDefaultDirection,
    WebMenuItemTagLeftToRight,
    WebMenuItemTagRightToLeft,
    WebMenuItemPDFSinglePageScrolling,
    WebMenuItemPDFFacingPagesScrolling,
    WebMenuItemTagInspectElement,
    WebMenuItemTagTextDirectionMenu,
    WebMenuItemTagTextDirectionDefault,
    WebMenuItemTagTextDirectionLeftToRight,
    WebMenuItemTagTextDirectionRightToLeft,
    WebMenuItemTagCorrectSpellingAutomatically,
    WebMenuItemTagSubstitutionsMenu,
    WebMenuItemTagShowSubstitutions,
    WebMenuItemTagSmartCopyPaste,
    WebMenuItemTagSmartQuotes,
    WebMenuItemTagSmartDashes,
    WebMenuItemTagSmartLinks,
    WebMenuItemTagTextReplacement,
    WebMenuItemTagTransformationsMenu,
    WebMenuItemTagMakeUpperCase,
    WebMenuItemTagMakeLowerCase,
    WebMenuItemTagCapitalize,
    WebMenuItemTagChangeBack,
    WebMenuItemTagBaseApplication = 10000
};

// Message Sources.
extern NSString *WebConsoleMessageHTMLMessageSource;
extern NSString *WebConsoleMessageXMLMessageSource;
extern NSString *WebConsoleMessageJSMessageSource;
extern NSString *WebConsoleMessageNetworkMessageSource;
extern NSString *WebConsoleMessageConsoleAPIMessageSource;
extern NSString *WebConsoleMessageOtherMessageSource;

// Message Types.
extern NSString *WebConsoleMessageLogMessageType;
extern NSString *WebConsoleMessageDirMessageType;
extern NSString *WebConsoleMessageDirXMLMessageType;
extern NSString *WebConsoleMessageTraceMessageType;
extern NSString *WebConsoleMessageStartGroupMessageType;
extern NSString *WebConsoleMessageStartGroupCollapsedMessageType;
extern NSString *WebConsoleMessageEndGroupMessageType;
extern NSString *WebConsoleMessageAssertMessageType;

// Message Levels.
extern NSString *WebConsoleMessageTipMessageLevel;
extern NSString *WebConsoleMessageLogMessageLevel;
extern NSString *WebConsoleMessageWarningMessageLevel;
extern NSString *WebConsoleMessageErrorMessageLevel;
extern NSString *WebConsoleMessageDebugMessageLevel;

@class WebSecurityOrigin;

@protocol WebGeolocationPolicyListener <NSObject>
- (void)allow;
- (void)deny;
@end

#if ENABLE_FULLSCREEN_API
@protocol WebKitFullScreenListener<NSObject>
- (void)webkitWillEnterFullScreen;
- (void)webkitDidEnterFullScreen;
- (void)webkitWillExitFullScreen;
- (void)webkitDidExitFullScreen;
@end
#endif

@interface NSObject (WebUIDelegatePrivate)

- (void)webView:(WebView *)webView addMessageToConsole:(NSDictionary *)message;

/*!
    @method webView:addMessageToConsole:withSource:
    @param webView The WebView sending the delegate method.
    @param message A dictionary representation of the console message.
    @param source Where the message came from. See WebConsoleMessageHTMLMessageSource and other source types.
    @discussion The dictionary contains the following keys:

    <dl>
        <dt>message</dt>
        <dd>The message itself.</dd>
        <dt>lineNumber</dt>
        <dd>If this came from a file, this is the line number in the file this message originates from.</dd>
        <dt>sourceURL</dt>
        <dd>If this came from a file, this is the URL to the file this message originates from.</dd>
        <dt>MessageSource</dt>
        <dd>
            Where the message came from. HTML, XML, JavaScript, CSS, etc.
            See WebConsoleMessageHTMLMessageSource and similar constants.
        </dd>
        <dt>MessageType</dt>
        <dd>
            Class of message. Start / End of a Group, a Log, Network related, etc.
            See WebConsoleMessageLogMessageType and similar constants.
        </dd>
        <dt>MessageLevel</dt>
        <dd>
            Severity level of the message. Tip, Log, Warning, etc.
            See WebConsoleMessageTipMessageLevel and similar constants.
        </dd>
    </dl>
*/
- (void)webView:(WebView *)webView addMessageToConsole:(NSDictionary *)message withSource:(NSString *)source;

- (NSView *)webView:(WebView *)webView plugInViewWithArguments:(NSDictionary *)arguments;

#if ENABLE_DASHBOARD_SUPPORT
// regions is an dictionary whose keys are regions label and values are arrays of WebDashboardRegions.
- (void)webView:(WebView *)webView dashboardRegionsChanged:(NSDictionary *)regions;
#endif

- (void)webView:(WebView *)sender dragImage:(NSImage *)anImage at:(NSPoint)viewLocation offset:(NSSize)initialOffset event:(NSEvent *)event pasteboard:(NSPasteboard *)pboard source:(id)sourceObj slideBack:(BOOL)slideFlag forView:(NSView *)view;
- (void)webView:(WebView *)sender didDrawRect:(NSRect)rect;
- (void)webView:(WebView *)sender didScrollDocumentInFrameView:(WebFrameView *)frameView;
// FIXME: If we ever make this method public, it should include a WebFrame parameter.
- (BOOL)webViewShouldInterruptJavaScript:(WebView *)sender;
- (void)webView:(WebView *)sender willPopupMenu:(NSMenu *)menu;
- (void)webView:(WebView *)sender contextMenuItemSelected:(NSMenuItem *)item forElement:(NSDictionary *)element;
- (void)webView:(WebView *)sender saveFrameView:(WebFrameView *)frameView showingPanel:(BOOL)showingPanel;
- (BOOL)webView:(WebView *)sender shouldHaltPlugin:(DOMNode *)pluginNode isWindowed:(BOOL)isWindowed pluginName:(NSString *)pluginName;
- (BOOL)webView:(WebView *)sender didPressMissingPluginButton:(DOMElement *)element;
/*!
    @method webView:frame:exceededDatabaseQuotaForSecurityOrigin:database:
    @param sender The WebView sending the delegate method.
    @param frame The WebFrame whose JavaScript initiated this call.
    @param origin The security origin that needs a larger quota.
    @param databaseIdentifier The identifier of the database involved.
*/
- (void)webView:(WebView *)sender frame:(WebFrame *)frame exceededDatabaseQuotaForSecurityOrigin:(WebSecurityOrigin *)origin database:(NSString *)databaseIdentifier;

/*!
    @method webView:exceededApplicationCacheOriginQuotaForSecurityOrigin:totalSpaceNeeded:
    @param sender The WebView sending the delegate method.
    @param origin The security origin that needs a larger quota.
    @param totalSpaceNeeded The amount of space needed to store the new manifest and keep all other
    previously stored caches for this origin.
    @discussion This method is called when a page attempts to store more in the Application Cache
    for an origin than was allowed by the quota (or default) set for the origin. This allows the
    quota to be increased for the security origin.
*/
- (void)webView:(WebView *)sender exceededApplicationCacheOriginQuotaForSecurityOrigin:(WebSecurityOrigin *)origin totalSpaceNeeded:(NSUInteger)totalSpaceNeeded;

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request windowFeatures:(NSDictionary *)features;

- (BOOL)webView:(WebView *)sender shouldReplaceUploadFile:(NSString *)path usingGeneratedFilename:(NSString **)filename;
- (NSString *)webView:(WebView *)sender generateReplacementFile:(NSString *)path;

/*!
    @method webView:decidePolicyForGeolocationRequestFromOrigin:frame:listener:
    @abstract 
    @param webView The WebView sending the delegate method.
    @param origin The security origin that would like to use Geolocation.
    @param frame The WebFrame whose JavaScript initiated this call.
    @param listener The object to call when the decision is made
*/
- (void)webView:(WebView *)webView decidePolicyForGeolocationRequestFromOrigin:(WebSecurityOrigin *)origin
                                                                         frame:(WebFrame *)frame
                                                                      listener:(id<WebGeolocationPolicyListener>)listener;

- (void)webView:(WebView *)sender elementDidFocusNode:(DOMNode *)node;
- (void)webView:(WebView *)sender elementDidBlurNode:(DOMNode *)node;

/*!
    @method webView:printFrame:
    @abstract Informs that a WebFrame needs to be printed
    @param webView The WebView sending the delegate method
    @param frameView The WebFrame needing to be printed
    @discussion This method is called when a script or user requests the page to be printed.
*/
- (void)webView:(WebView *)sender printFrame:(WebFrame *)frame;

#if ENABLE_FULLSCREEN_API
- (BOOL)webView:(WebView *)sender supportsFullScreenForElement:(DOMElement *)element;
- (void)webView:(WebView *)sender enterFullScreenForElement:(DOMElement *)element;
- (void)webView:(WebView *)sender exitFullScreenForElement:(DOMElement *)element;
#endif

- (void)webView:(WebView *)sender didDrawFrame:(WebFrame *)frame;

@end
