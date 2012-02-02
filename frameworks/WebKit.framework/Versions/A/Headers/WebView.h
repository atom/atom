/*
 * Copyright (C) 2003, 2004, 2005, 2006 Apple Computer, Inc.  All rights reserved.
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

@class DOMCSSStyleDeclaration;
@class DOMDocument;
@class DOMElement;
@class DOMNode;
@class DOMRange;

@class WebArchive;
@class WebBackForwardList;
@class WebDataSource;
@class WebFrame;
@class WebFrameView;
@class WebHistoryItem;
@class WebPreferences;
@class WebScriptObject;
@class WebViewPrivate;

// Element dictionary keys
extern NSString *WebElementDOMNodeKey;          // DOMNode of the element
extern NSString *WebElementFrameKey;            // WebFrame of the element
extern NSString *WebElementImageAltStringKey;   // NSString of the ALT attribute of the image element
extern NSString *WebElementImageKey;            // NSImage of the image element
extern NSString *WebElementImageRectKey;        // NSValue of an NSRect, the rect of the image element
extern NSString *WebElementImageURLKey;         // NSURL of the image element
extern NSString *WebElementIsSelectedKey;       // NSNumber of BOOL indicating whether the element is selected or not 
extern NSString *WebElementLinkURLKey;          // NSURL of the link if the element is within an anchor
extern NSString *WebElementLinkTargetFrameKey;  // WebFrame of the target of the anchor
extern NSString *WebElementLinkTitleKey;        // NSString of the title of the anchor
extern NSString *WebElementLinkLabelKey;        // NSString of the text within the anchor

/*
    @discussion Notifications sent by WebView to mark the progress of loads.
    @constant WebViewProgressStartedNotification Posted whenever a load begins in the WebView, including
    a load that is initiated in a subframe.  After receiving this notification zero or more
    WebViewProgressEstimateChangedNotifications will be sent.  The userInfo will be nil.
    @constant WebViewProgressEstimateChangedNotification Posted whenever the value of
    estimatedProgress changes.  The userInfo will be nil.
    @constant WebViewProgressFinishedNotification Posted when the load for a WebView has finished.
    The userInfo will be nil.
*/
extern NSString *WebViewProgressStartedNotification;
extern NSString *WebViewProgressEstimateChangedNotification;
extern NSString *WebViewProgressFinishedNotification;

/*!
    @class WebView
    WebView manages the interaction between WebFrameViews and WebDataSources.  Modification
    of the policies and behavior of the WebKit is largely managed by WebViews and their
    delegates.
    
    <p>
    Typical usage:
    </p>
    <pre>
    WebView *webView;
    WebFrame *mainFrame;
    
    webView  = [[WebView alloc] initWithFrame: NSMakeRect (0,0,640,480)];
    mainFrame = [webView mainFrame];
    [mainFrame loadRequest:request];
    </pre>
    
    WebViews have the following delegates:  WebUIDelegate, WebResourceLoadDelegate,
    WebFrameLoadDelegate, and WebPolicyDelegate.
    
    WebKit depends on the WebView's WebUIDelegate for all window
    related management, including opening new windows and controlling the user interface
    elements in those windows.
    
    WebResourceLoadDelegate is used to monitor the progress of resources as they are
    loaded.  This delegate may be used to present users with a progress monitor.
    
    The WebFrameLoadDelegate receives messages when the URL in a WebFrame is
    changed.
    
    WebView's WebPolicyDelegate can make determinations about how
    content should be handled, based on the resource's URL and MIME type.
*/
@interface WebView : NSView
{
@private
    WebViewPrivate *_private;
}

/*!
    @method canShowMIMEType:
    @abstract Checks if the WebKit can show content of a certain MIME type.
    @param MIMEType The MIME type to check.
    @result YES if the WebKit can show content with MIMEtype.
*/
+ (BOOL)canShowMIMEType:(NSString *)MIMEType;


/*!
     @method canShowMIMETypeAsHTML:
     @abstract Checks if the the MIME type is a type that the WebKit will interpret as HTML.
     @param MIMEType The MIME type to check.
     @result YES if the MIMEtype in an HTML type.
*/
+ (BOOL)canShowMIMETypeAsHTML:(NSString *)MIMEType;

/*!
    @method MIMETypesShownAsHTML
    @result Returns an array of NSStrings that describe the MIME types
    WebKit will attempt to render as HTML.
*/
+ (NSArray *)MIMETypesShownAsHTML;

/*!
    @method setMIMETypesShownAsHTML:
    @discussion Sets the array of NSString MIME types that WebKit will
    attempt to render as HTML.  Typically you will retrieve the built-in
    array using MIMETypesShownAsHTML and add additional MIME types to that
    array.
*/
+ (void)setMIMETypesShownAsHTML:(NSArray *)MIMETypes;

/*!
    @method URLFromPasteboard:
    @abstract Returns a URL from a pasteboard
    @param pasteboard The pasteboard with a URL
    @result A URL if the pasteboard has one. Nil if it does not.
    @discussion This method differs than NSURL's URLFromPasteboard method in that it tries multiple pasteboard types
    including NSURLPboardType to find a URL on the pasteboard.
*/
+ (NSURL *)URLFromPasteboard:(NSPasteboard *)pasteboard;

/*!
    @method URLTitleFromPasteboard:
    @abstract Returns a URL title from a pasteboard
    @param pasteboard The pasteboard with a URL title
    @result A URL title if the pasteboard has one. Nil if it does not.
    @discussion This method returns a title that refers a URL on the pasteboard. An example of this is the link label
    which is the text inside the anchor tag.
*/
+ (NSString *)URLTitleFromPasteboard:(NSPasteboard *)pasteboard;

/*!
    @method registerURLSchemeAsLocal:
    @abstract Adds the scheme to the list of schemes to be treated as local.
    @param scheme The scheme to register
*/
+ (void)registerURLSchemeAsLocal:(NSString *)scheme;

/*!
    @method initWithFrame:frameName:groupName:
    @abstract The designated initializer for WebView.
    @discussion Initialize a WebView with the supplied parameters. This method will 
    create a main WebFrame with the view. Passing a top level frame name is useful if you
    handle a targetted frame navigation that would normally open a window in some other 
    way that still ends up creating a new WebView.
    @param frame The frame used to create the view.
    @param frameName The name to use for the top level frame. May be nil.
    @param groupName The name of the webView set to which this webView will be added.  May be nil.
    @result Returns an initialized WebView.
*/
- (id)initWithFrame:(NSRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName;

/*!
    @method close
    @abstract Closes the receiver, unloading its web page and canceling any pending loads.
    Once the receiver has closed, it will no longer respond to requests or fire delegate methods.
    (However, the -close method itself may fire delegate methods.)
    @discussion A garbage collected application is required to call close when the receiver is no longer needed.
    The close method will be called automatically when the window or hostWindow closes and shouldCloseWithWindow returns YES.
    A non-garbage collected application can still call close, providing a convenient way to prevent receiver
    from doing any more loading and firing any future delegate methods.
*/
- (void)close;

/*!
    @method setShouldCloseWithWindow:
    @abstract Set whether the receiver closes when either it's window or hostWindow closes.
    @param close YES if the receiver should close when either it's window or hostWindow closes, otherwise NO.
*/
- (void)setShouldCloseWithWindow:(BOOL)close;

/*!
    @method shouldCloseWithWindow
    @abstract Returns whether the receiver closes when either it's window or hostWindow closes.
    @discussion Defaults to YES in garbage collected applications, otherwise NO to maintain backwards compatibility.
    @result YES if the receiver closes when either it's window or hostWindow closes, otherwise NO.
*/
- (BOOL)shouldCloseWithWindow;

/*!
    @method setUIDelegate:
    @abstract Set the WebView's WebUIDelegate.
    @param delegate The WebUIDelegate to set as the delegate.
*/    
- (void)setUIDelegate:(id)delegate;

/*!
    @method UIDelegate
    @abstract Return the WebView's WebUIDelegate.
    @result The WebView's WebUIDelegate.
*/
- (id)UIDelegate;

/*!
    @method setResourceLoadDelegate:
    @abstract Set the WebView's WebResourceLoadDelegate load delegate.
    @param delegate The WebResourceLoadDelegate to set as the load delegate.
*/
- (void)setResourceLoadDelegate:(id)delegate;

/*!
    @method resourceLoadDelegate
    @result Return the WebView's WebResourceLoadDelegate.
*/    
- (id)resourceLoadDelegate;

/*!
    @method setDownloadDelegate:
    @abstract Set the WebView's WebDownloadDelegate.
    @discussion The download delegate is retained by WebDownload when any downloads are in progress.
    @param delegate The WebDownloadDelegate to set as the download delegate.
*/    
- (void)setDownloadDelegate:(id)delegate;

/*!
    @method downloadDelegate
    @abstract Return the WebView's WebDownloadDelegate.
    @result The WebView's WebDownloadDelegate.
*/    
- (id)downloadDelegate;

/*!
    @method setFrameLoadDelegate:
    @abstract Set the WebView's WebFrameLoadDelegate delegate.
    @param delegate The WebFrameLoadDelegate to set as the delegate.
*/    
- (void)setFrameLoadDelegate:(id)delegate;

/*!
    @method frameLoadDelegate
    @abstract Return the WebView's WebFrameLoadDelegate delegate.
    @result The WebView's WebFrameLoadDelegate delegate.
*/    
- (id)frameLoadDelegate;

/*!
    @method setPolicyDelegate:
    @abstract Set the WebView's WebPolicyDelegate delegate.
    @param delegate The WebPolicyDelegate to set as the delegate.
*/    
- (void)setPolicyDelegate:(id)delegate;

/*!
    @method policyDelegate
    @abstract Return the WebView's WebPolicyDelegate.
    @result The WebView's WebPolicyDelegate.
*/    
- (id)policyDelegate;

/*!
    @method mainFrame
    @abstract Return the top level frame.  
    @discussion Note that even document that are not framesets will have a
    mainFrame.
    @result The main frame.
*/    
- (WebFrame *)mainFrame;

/*!
    @method selectedFrame
    @abstract Return the frame that has the active selection.  
    @discussion Returns the frame that contains the first responder, if any. Otherwise returns the
    frame that contains a non-zero-length selection, if any. Returns nil if no frame meets these criteria.
    @result The selected frame.
*/
- (WebFrame *)selectedFrame;

/*!
    @method backForwardList
    @result The backforward list for this webView.
*/    
- (WebBackForwardList *)backForwardList;

/*!
    @method setMaintainsBackForwardList:
    @abstract Enable or disable the use of a backforward list for this webView.
    @param flag Turns use of the back forward list on or off
*/    
- (void)setMaintainsBackForwardList:(BOOL)flag;

/*!
    @method goBack
    @abstract Go back to the previous URL in the backforward list.
    @result YES if able to go back in the backforward list, NO otherwise.
*/    
- (BOOL)goBack;

/*!
    @method goForward
    @abstract Go forward to the next URL in the backforward list.
    @result YES if able to go forward in the backforward list, NO otherwise.
*/    
- (BOOL)goForward;

/*!
    @method goToBackForwardItem:
    @abstract Go back or forward to an item in the backforward list.
    @result YES if able to go to the item, NO otherwise.
*/    
- (BOOL)goToBackForwardItem:(WebHistoryItem *)item;

/*!
    @method setTextSizeMultiplier:
    @abstract Change the size of the text rendering in views managed by this webView.
    @param multiplier A fractional percentage value, 1.0 is 100%.
*/    
- (void)setTextSizeMultiplier:(float)multiplier;

/*!
    @method textSizeMultiplier
    @result The text size multipler.
*/    
- (float)textSizeMultiplier;

/*!
    @method setApplicationNameForUserAgent:
    @abstract Set the application name. 
    @discussion This name will be used in user-agent strings
    that are chosen for best results in rendering web pages.
    @param applicationName The application name
*/
- (void)setApplicationNameForUserAgent:(NSString *)applicationName;

/*!
    @method applicationNameForUserAgent
    @result The name of the application as used in the user-agent string.
*/
- (NSString *)applicationNameForUserAgent;

/*!
    @method setCustomUserAgent:
    @abstract Set the user agent. 
    @discussion Setting this means that the webView should use this user-agent string
    instead of constructing a user-agent string for each URL. Setting it to nil
    causes the webView to construct the user-agent string for each URL
    for best results rendering web pages.
    @param userAgentString The user agent description
*/
- (void)setCustomUserAgent:(NSString *)userAgentString;

/*!
    @method customUserAgent
    @result The custom user-agent string or nil if no custom user-agent string has been set.
*/
- (NSString *)customUserAgent;

/*!
    @method userAgentForURL:
    @abstract Get the appropriate user-agent string for a particular URL.
    @param URL The URL.
    @result The user-agent string for the supplied URL.
*/
- (NSString *)userAgentForURL:(NSURL *)URL;


/*!
    @method supportsTextEncoding
    @abstract Find out if the current web page supports text encodings.
    @result YES if the document view of the current web page can
    support different text encodings.
*/
- (BOOL)supportsTextEncoding;

/*!
    @method setCustomTextEncodingName:
    @discussion Make the page display with a different text encoding; stops any load in progress.
    The text encoding passed in overrides the normal text encoding smarts including
    what's specified in a web page's header or HTTP response.
    The text encoding automatically goes back to the default when the top level frame
    changes to a new location.
    Setting the text encoding name to nil makes the webView use default encoding rules.
    @param encoding The text encoding name to use to display a page or nil.
*/
- (void)setCustomTextEncodingName:(NSString *)encodingName;

/*!
    @method customTextEncodingName
    @result The custom text encoding name or nil if no custom text encoding name has been set.
*/
- (NSString *)customTextEncodingName;

/*!
    @method setMediaStyle:
    @discussion Set the media style for the WebView.  The mediaStyle will override the normal value
    of the CSS media property.  Setting the value to nil will restore the normal value.
    @param mediaStyle The value to use for the CSS media property.
*/
- (void)setMediaStyle:(NSString *)mediaStyle;

/*!
    @method mediaStyle
    @result mediaStyle The value to use for the CSS media property, as set by setMediaStyle:.  It
    will be nil unless set by that method.
*/
- (NSString *)mediaStyle;

/*!
    @method stringByEvaluatingJavaScriptFromString:
    @param script The text of the JavaScript.
    @result The result of the script, converted to a string, or nil for failure.
*/
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;

/*!
    @method windowScriptObject
    @discussion windowScriptObject return a WebScriptObject that represents the
    window object from the script environment.
    @result Returns the window object from the script environment.
*/
- (WebScriptObject *)windowScriptObject;

/*!
    @method setPreferences:
    @param preferences The preferences to use for the webView.
    @abstract Override the standard setting for the webView. 
*/
- (void)setPreferences: (WebPreferences *)prefs;

/*!
    @method preferences
    @result Returns the preferences used by this webView.
    @discussion This method will return [WebPreferences standardPreferences] if no
    other instance of WebPreferences has been set.
*/
- (WebPreferences *)preferences;

/*!
    @method setPreferencesIdentifier:
    @param anIdentifier The string to use a prefix for storing values for this WebView in the user
    defaults database.
    @discussion If the WebPreferences for this WebView are stored in the user defaults database, the
    string set in this method will be used a key prefix.
*/
- (void)setPreferencesIdentifier:(NSString *)anIdentifier;

/*!
    @method preferencesIdentifier
    @result Returns the WebPreferences key prefix.
*/
- (NSString *)preferencesIdentifier;


/*!
    @method setHostWindow:
    @param hostWindow The host window for the web view.
    @discussion Parts of WebKit (such as plug-ins and JavaScript) depend on a window to function
    properly. Set a host window so these parts continue to function even when the web view is
    not in an actual window.
*/
- (void)setHostWindow:(NSWindow *)hostWindow;

/*!
    @method hostWindow
    @result The host window for the web view.
*/
- (NSWindow *)hostWindow;

/*!
    @method searchFor:direction:caseSensitive:
    @abstract Searches a document view for a string and highlights the string if it is found.
    Starts the search from the current selection.  Will search across all frames.
    @param string The string to search for.
    @param forward YES to search forward, NO to seach backwards.
    @param caseFlag YES to for case-sensitive search, NO for case-insensitive search.
    @result YES if found, NO if not found.
*/
- (BOOL)searchFor:(NSString *)string direction:(BOOL)forward caseSensitive:(BOOL)caseFlag wrap:(BOOL)wrapFlag;

/*!
    @method registerViewClass:representationClass:forMIMEType:
    @discussion Register classes that implement WebDocumentView and WebDocumentRepresentation respectively.
    A document class may register for a primary MIME type by excluding
    a subtype, i.e. "video/" will match the document class with
    all video types.  More specific matching takes precedence
    over general matching.
    @param viewClass The WebDocumentView class to use to render data for a given MIME type.
    @param representationClass The WebDocumentRepresentation class to use to represent data of the given MIME type.
    @param MIMEType The MIME type to represent with an object of the given class.
*/
+ (void)registerViewClass:(Class)viewClass representationClass:(Class)representationClass forMIMEType:(NSString *)MIMEType;


/*!
    @method setGroupName:
    @param groupName The name of the group for this WebView.
    @discussion JavaScript may access named frames within the same group. 
*/
- (void)setGroupName:(NSString *)groupName;

/*!
    @method groupName
    @discussion The group name for this WebView.
*/
- (NSString *)groupName;

/*!
    @method estimatedProgress
    @discussion An estimate of the percent complete for a document load.  This
    value will range from 0 to 1.0 and, once a load completes, will remain at 1.0 
    until a new load starts, at which point it will be reset to 0.  The value is an
    estimate based on the total number of bytes expected to be received
    for a document, including all it's possible subresources.  For more accurate progress
    indication it is recommended that you implement a WebFrameLoadDelegate and a
    WebResourceLoadDelegate.
*/
- (double)estimatedProgress;

/*!
    @method isLoading
    @discussion Returns YES if there are any pending loads.
*/
- (BOOL)isLoading;

/*!
    @method elementAtPoint:
    @param point A point in the coordinates of the WebView
    @result An element dictionary describing the point
*/
- (NSDictionary *)elementAtPoint:(NSPoint)point;

/*!
    @method pasteboardTypesForSelection
    @abstract Returns the pasteboard types that WebView can use for the current selection
*/
- (NSArray *)pasteboardTypesForSelection;

/*!
    @method writeSelectionWithPasteboardTypes:toPasteboard:
    @abstract Writes the current selection to the pasteboard
    @param types The types that WebView will write to the pasteboard
    @param pasteboard The pasteboard to write to
*/
- (void)writeSelectionWithPasteboardTypes:(NSArray *)types toPasteboard:(NSPasteboard *)pasteboard;

/*!
    @method pasteboardTypesForElement:
    @abstract Returns the pasteboard types that WebView can use for an element
    @param element The element
*/
- (NSArray *)pasteboardTypesForElement:(NSDictionary *)element;

/*!
    @method writeElement:withPasteboardTypes:toPasteboard:
    @abstract Writes an element to the pasteboard
    @param element The element to write to the pasteboard
    @param types The types that WebView will write to the pasteboard
    @param pasteboard The pasteboard to write to
*/
- (void)writeElement:(NSDictionary *)element withPasteboardTypes:(NSArray *)types toPasteboard:(NSPasteboard *)pasteboard;

/*!
    @method moveDragCaretToPoint:
    @param point A point in the coordinates of the WebView
    @discussion This method moves the caret that shows where something being dragged will be dropped. It may cause the WebView to scroll
    to make the new position of the drag caret visible.
*/
- (void)moveDragCaretToPoint:(NSPoint)point;

/*!
    @method removeDragCaret
    @abstract Removes the drag caret from the WebView
*/
- (void)removeDragCaret;

/*!
    @method setDrawsBackground:
    @param drawsBackround YES to cause the receiver to draw a default white background, NO otherwise.
    @abstract Sets whether the receiver draws a default white background when the loaded page has no background specified.
*/
- (void)setDrawsBackground:(BOOL)drawsBackround;

/*!
    @method drawsBackground
    @result Returns YES if the receiver draws a default white background, NO otherwise.
*/
- (BOOL)drawsBackground;

/*!
    @method setShouldUpdateWhileOffscreen:
    @abstract Sets whether the receiver must update even when it is not in a window that is currently visible.
    @param updateWhileOffscreen whether the receiver is required to render updates to the web page when it is not in a visible window.
    @abstract If set to NO, then whenever the web view is not in a visible window, updates to the web page will not necessarily be rendered in the view.
    However, when the window is made visible, the view will be updated automatically. Not updating while hidden can improve performance. If set to is YES,
    hidden web views are always updated. This is the default.
*/
- (void)setShouldUpdateWhileOffscreen:(BOOL)updateWhileOffscreen;

/*!
    @method shouldUpdateWhileOffscreen
    @result Returns whether the web view is always updated even when it is not in a window that is currently visible.
*/
- (BOOL)shouldUpdateWhileOffscreen;

/*!
    @method setMainFrameURL:
    @param URLString The URL to load in the mainFrame.
*/
- (void)setMainFrameURL:(NSString *)URLString;

/*!
    @method mainFrameURL
    @result Returns the main frame's current URL.
*/
- (NSString *)mainFrameURL;

/*!
    @method mainFrameDocument
    @result Returns the main frame's DOMDocument.
*/
- (DOMDocument *)mainFrameDocument;

/*!
    @method mainFrameTitle
    @result Returns the main frame's title if any, otherwise an empty string.
*/
- (NSString *)mainFrameTitle;

/*!
    @method mainFrameIcon
    @discussion The methods returns the site icon for the current page loaded in the mainFrame.
    @result Returns the main frame's icon if any, otherwise nil.
*/
- (NSImage *)mainFrameIcon;

@end


@interface WebView (WebIBActions) <NSUserInterfaceValidations>
- (IBAction)takeStringURLFrom:(id)sender;
- (IBAction)stopLoading:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)reloadFromOrigin:(id)sender;
- (BOOL)canGoBack;
- (IBAction)goBack:(id)sender;
- (BOOL)canGoForward;
- (IBAction)goForward:(id)sender;
- (BOOL)canMakeTextLarger;
- (IBAction)makeTextLarger:(id)sender;
- (BOOL)canMakeTextSmaller;
- (IBAction)makeTextSmaller:(id)sender;
- (BOOL)canMakeTextStandardSize;
- (IBAction)makeTextStandardSize:(id)sender;
- (IBAction)toggleContinuousSpellChecking:(id)sender;
- (IBAction)toggleSmartInsertDelete:(id)sender;
@end


// WebView editing support

extern NSString * const WebViewDidBeginEditingNotification;
extern NSString * const WebViewDidChangeNotification;
extern NSString * const WebViewDidEndEditingNotification;
extern NSString * const WebViewDidChangeTypingStyleNotification;
extern NSString * const WebViewDidChangeSelectionNotification;

@interface WebView (WebViewCSS)
- (DOMCSSStyleDeclaration *)computedStyleForElement:(DOMElement *)element pseudoElement:(NSString *)pseudoElement;
@end

@interface WebView (WebViewEditing)
- (DOMRange *)editableDOMRangeForPoint:(NSPoint)point;
- (void)setSelectedDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)selectionAffinity;
- (DOMRange *)selectedDOMRange;
- (NSSelectionAffinity)selectionAffinity;
- (BOOL)maintainsInactiveSelection;
- (void)setEditable:(BOOL)flag;
- (BOOL)isEditable;
- (void)setTypingStyle:(DOMCSSStyleDeclaration *)style;
- (DOMCSSStyleDeclaration *)typingStyle;
- (void)setSmartInsertDeleteEnabled:(BOOL)flag;
- (BOOL)smartInsertDeleteEnabled;
- (void)setContinuousSpellCheckingEnabled:(BOOL)flag;
- (BOOL)isContinuousSpellCheckingEnabled;
- (NSInteger)spellCheckerDocumentTag;
- (NSUndoManager *)undoManager;
- (void)setEditingDelegate:(id)delegate;
- (id)editingDelegate;
- (DOMCSSStyleDeclaration *)styleDeclarationWithText:(NSString *)text;
@end

@interface WebView (WebViewUndoableEditing)
- (void)replaceSelectionWithNode:(DOMNode *)node; 
- (void)replaceSelectionWithText:(NSString *)text;    
- (void)replaceSelectionWithMarkupString:(NSString *)markupString;
- (void)replaceSelectionWithArchive:(WebArchive *)archive;
- (void)deleteSelection;    
- (void)applyStyle:(DOMCSSStyleDeclaration *)style;
@end

@interface WebView (WebViewEditingActions)

- (void)copy:(id)sender;
- (void)cut:(id)sender;
- (void)paste:(id)sender;
- (void)copyFont:(id)sender;
- (void)pasteFont:(id)sender;
- (void)delete:(id)sender;
- (void)pasteAsPlainText:(id)sender;
- (void)pasteAsRichText:(id)sender;

- (void)changeFont:(id)sender;
- (void)changeAttributes:(id)sender;
- (void)changeDocumentBackgroundColor:(id)sender;
- (void)changeColor:(id)sender;

- (void)alignCenter:(id)sender;
- (void)alignJustified:(id)sender;
- (void)alignLeft:(id)sender;
- (void)alignRight:(id)sender;

- (void)checkSpelling:(id)sender;
- (void)showGuessPanel:(id)sender;
- (void)performFindPanelAction:(id)sender;

- (void)startSpeaking:(id)sender;
- (void)stopSpeaking:(id)sender;

- (void)moveToBeginningOfSentence:(id)sender;
- (void)moveToBeginningOfSentenceAndModifySelection:(id)sender;
- (void)moveToEndOfSentence:(id)sender;
- (void)moveToEndOfSentenceAndModifySelection:(id)sender;
- (void)selectSentence:(id)sender;

/* 
The following methods are declared in NSResponder.h.
WebView overrides each method in this list, providing
a custom implementation for each.
    
- (void)capitalizeWord:(id)sender;
- (void)centerSelectionInVisibleArea:(id)sender;
- (void)changeCaseOfLetter:(id)sender;
- (void)complete:(id)sender;
- (void)deleteBackward:(id)sender;
- (void)deleteBackwardByDecomposingPreviousCharacter:(id)sender;
- (void)deleteForward:(id)sender;
- (void)deleteToBeginningOfLine:(id)sender;
- (void)deleteToBeginningOfParagraph:(id)sender;
- (void)deleteToEndOfLine:(id)sender;
- (void)deleteToEndOfParagraph:(id)sender;
- (void)deleteWordBackward:(id)sender;
- (void)deleteWordForward:(id)sender;
- (void)indent:(id)sender;
- (void)insertBacktab:(id)sender;
- (void)insertNewline:(id)sender;
- (void)insertParagraphSeparator:(id)sender;
- (void)insertTab:(id)sender;
- (void)lowercaseWord:(id)sender;
- (void)moveBackward:(id)sender;
- (void)moveBackwardAndModifySelection:(id)sender;
- (void)moveDown:(id)sender;
- (void)moveDownAndModifySelection:(id)sender;
- (void)moveForward:(id)sender;
- (void)moveForwardAndModifySelection:(id)sender;
- (void)moveLeft:(id)sender;
- (void)moveLeftAndModifySelection:(id)sender;
- (void)moveRight:(id)sender;
- (void)moveRightAndModifySelection:(id)sender;
- (void)moveToBeginningOfDocument:(id)sender;
- (void)moveToBeginningOfDocumentAndModifySelection:(id)sender;
- (void)moveToBeginningOfLine:(id)sender;
- (void)moveToBeginningOfLineAndModifySelection:(id)sender;
- (void)moveToBeginningOfParagraph:(id)sender;
- (void)moveToBeginningOfParagraphAndModifySelection:(id)sender;
- (void)moveToEndOfDocument:(id)sender;
- (void)moveToEndOfDocumentAndModifySelection:(id)sender;
- (void)moveToEndOfLine:(id)sender;
- (void)moveToEndOfLineAndModifySelection:(id)sender;
- (void)moveToEndOfParagraph:(id)sender;
- (void)moveToEndOfParagraphAndModifySelection:(id)sender;
- (void)moveUp:(id)sender;
- (void)moveUpAndModifySelection:(id)sender;
- (void)moveWordBackward:(id)sender;
- (void)moveWordBackwardAndModifySelection:(id)sender;
- (void)moveWordForward:(id)sender;
- (void)moveWordForwardAndModifySelection:(id)sender;
- (void)moveWordLeft:(id)sender;
- (void)moveWordLeftAndModifySelection:(id)sender;
- (void)moveWordRight:(id)sender;
- (void)moveWordRightAndModifySelection:(id)sender;
- (void)pageDown:(id)sender;
- (void)pageUp:(id)sender;
- (void)scrollLineDown:(id)sender;
- (void)scrollLineUp:(id)sender;
- (void)scrollPageDown:(id)sender;
- (void)scrollPageUp:(id)sender;
- (void)selectAll:(id)sender;
- (void)selectLine:(id)sender;
- (void)selectParagraph:(id)sender;
- (void)selectWord:(id)sender;
- (void)uppercaseWord:(id)sender;
*/
 
@end
