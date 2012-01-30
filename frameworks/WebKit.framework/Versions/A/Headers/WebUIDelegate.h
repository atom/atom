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
#import <Foundation/NSURLRequest.h>
#import <JavaScriptCore/WebKitAvailability.h>

/*!
    @enum WebMenuItemTag
    @discussion Each menu item in the default menu items array passed in
    contextMenuItemsForElement:defaultMenuItems: has its tag set to one of the WebMenuItemTags.
    When iterating through the default menu items array, use the tag to differentiate between them.
*/

enum {
    WebMenuItemTagOpenLinkInNewWindow=1,
    WebMenuItemTagDownloadLinkToDisk,
    WebMenuItemTagCopyLinkToClipboard,
    WebMenuItemTagOpenImageInNewWindow,
    WebMenuItemTagDownloadImageToDisk,
    WebMenuItemTagCopyImageToClipboard,
    WebMenuItemTagOpenFrameInNewWindow,
    WebMenuItemTagCopy,
    WebMenuItemTagGoBack,
    WebMenuItemTagGoForward,
    WebMenuItemTagStop,
    WebMenuItemTagReload,
    WebMenuItemTagCut,
    WebMenuItemTagPaste,
    WebMenuItemTagSpellingGuess,
    WebMenuItemTagNoGuessesFound,
    WebMenuItemTagIgnoreSpelling,
    WebMenuItemTagLearnSpelling,
    WebMenuItemTagOther,
    WebMenuItemTagSearchInSpotlight,
    WebMenuItemTagSearchWeb,
    WebMenuItemTagLookUpInDictionary,
    WebMenuItemTagOpenWithDefaultApplication,
    WebMenuItemPDFActualSize,
    WebMenuItemPDFZoomIn,
    WebMenuItemPDFZoomOut,
    WebMenuItemPDFAutoSize,
    WebMenuItemPDFSinglePage,
    WebMenuItemPDFFacingPages,
    WebMenuItemPDFContinuous,
    WebMenuItemPDFNextPage,
    WebMenuItemPDFPreviousPage,
};

/*!
    @enum WebDragDestinationAction
    @abstract Actions that the destination of a drag can perform.
    @constant WebDragDestinationActionNone No action
    @constant WebDragDestinationActionDHTML Allows DHTML (such as JavaScript) to handle the drag
    @constant WebDragDestinationActionEdit Allows editable documents to be edited from the drag
    @constant WebDragDestinationActionLoad Allows a location change from the drag
    @constant WebDragDestinationActionAny Allows any of the above to occur
*/
typedef enum {
    WebDragDestinationActionNone    = 0,
    WebDragDestinationActionDHTML   = 1,
    WebDragDestinationActionEdit    = 2,
    WebDragDestinationActionLoad    = 4,
    WebDragDestinationActionAny     = UINT_MAX
} WebDragDestinationAction;

/*!
    @enum WebDragSourceAction
    @abstract Actions that the source of a drag can perform.
    @constant WebDragSourceActionNone No action
    @constant WebDragSourceActionDHTML Allows DHTML (such as JavaScript) to start a drag
    @constant WebDragSourceActionImage Allows an image drag to occur
    @constant WebDragSourceActionLink Allows a link drag to occur
    @constant WebDragSourceActionSelection Allows a selection drag to occur
    @constant WebDragSourceActionAny Allows any of the above to occur
*/
typedef enum {
    WebDragSourceActionNone         = 0,
    WebDragSourceActionDHTML        = 1,
    WebDragSourceActionImage        = 2,
    WebDragSourceActionLink         = 4,
    WebDragSourceActionSelection    = 8,
    WebDragSourceActionAny          = UINT_MAX
} WebDragSourceAction;

/*!
    @protocol WebOpenPanelResultListener
    @discussion This protocol is used to call back with the results of
    the file open panel requested by runOpenPanelForFileButtonWithResultListener:
*/
@protocol WebOpenPanelResultListener <NSObject>

/*!
    @method chooseFilename:
    @abstract Call this method to return a filename from the file open panel.
    @param fileName
*/
- (void)chooseFilename:(NSString *)fileName;

/*!
    @method chooseFilenames:
    @abstract Call this method to return an array of filenames from the file open panel.
    @param fileNames
*/
- (void)chooseFilenames:(NSArray *)fileNames WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_IN_WEBKIT_VERSION_4_0);

/*!
    @method cancel
    @abstract Call this method to indicate that the file open panel was cancelled.
*/
- (void)cancel;

@end

@class WebFrame;
@class WebFrameView;
@class WebView;

/*!
    @category WebUIDelegate
    @discussion A class that implements WebUIDelegate provides
    window-related methods that may be used by Javascript, plugins and
    other aspects of web pages. These methods are used to open new
    windows and control aspects of existing windows.
*/
@interface NSObject (WebUIDelegate)

/*!
    @method webView:createWebViewWithRequest:
    @abstract Create a new window and begin to load the specified request.
    @discussion The newly created window is hidden, and the window operations delegate on the
    new WebViews will get a webViewShow: call.
    @param sender The WebView sending the delegate method.
    @param request The request to load.
    @result The WebView for the new window.
*/
- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request;

/*!
    @method webViewShow:
    @param sender The WebView sending the delegate method.
    @abstract Show the window that contains the top level view of the WebView,
    ordering it frontmost.
    @discussion This will only be called just after createWindowWithRequest:
    is used to create a new window.
*/
- (void)webViewShow:(WebView *)sender;

/*!
    @method webView:createWebViewModalDialogWithRequest:
    @abstract Create a new window and begin to load the specified request.
    @discussion The newly created window is hidden, and the window operations delegate on the
    new WebViews will get a webViewShow: call.
    @param sender The WebView sending the delegate method.
    @param request The request to load.
    @result The WebView for the new window.
*/
- (WebView *)webView:(WebView *)sender createWebViewModalDialogWithRequest:(NSURLRequest *)request;

/*!
    @method webViewRunModal:
    @param sender The WebView sending the delegate method.
    @abstract Show the window that contains the top level view of the WebView,
    ordering it frontmost. The window should be run modal in the application.
    @discussion This will only be called just after createWebViewModalDialogWithRequest:
    is used to create a new window.
*/
- (void)webViewRunModal:(WebView *)sender;

/*!
    @method webViewClose:
    @abstract Close the current window. 
    @param sender The WebView sending the delegate method.
    @discussion Clients showing multiple views in one window may
    choose to close only the one corresponding to this
    WebView. Other clients may choose to ignore this method
    entirely.
*/
- (void)webViewClose:(WebView *)sender;

/*!
    @method webViewFocus:
    @abstract Focus the current window (i.e. makeKeyAndOrderFront:).
    @param The WebView sending the delegate method.
    @discussion Clients showing multiple views in one window may want to
    also do something to focus the one corresponding to this WebView.
*/
- (void)webViewFocus:(WebView *)sender;

/*!
    @method webViewUnfocus:
    @abstract Unfocus the current window.
    @param sender The WebView sending the delegate method.
    @discussion Clients showing multiple views in one window may want to
    also do something to unfocus the one corresponding to this WebView.
*/
- (void)webViewUnfocus:(WebView *)sender;

/*!
    @method webViewFirstResponder:
    @abstract Get the first responder for this window.
    @param sender The WebView sending the delegate method.
    @discussion This method should return the focused control in the
    WebView's view, if any. If the view is out of the window
    hierarchy, this might return something than calling firstResponder
    on the real NSWindow would. It's OK to return either nil or the
    real first responder if some control not in the window has focus.
*/
- (NSResponder *)webViewFirstResponder:(WebView *)sender;

/*!
    @method webView:makeFirstResponder:
    @abstract Set the first responder for this window.
    @param sender The WebView sending the delegate method.
    @param responder The responder to make first (will always be a view)
    @discussion responder will always be a view that is in the view
    subhierarchy of the top-level web view for this WebView. If the
    WebView's top level view is currently out of the view
    hierarchy, it may be desirable to save the first responder
    elsewhere, or possibly ignore this call.
*/
- (void)webView:(WebView *)sender makeFirstResponder:(NSResponder *)responder;

/*!
    @method webView:setStatusText:
    @abstract Set the window's status display, if any, to the specified string.
    @param sender The WebView sending the delegate method.
    @param text The status text to set
*/
- (void)webView:(WebView *)sender setStatusText:(NSString *)text;

/*!
    @method webViewStatusText:
    @abstract Get the currently displayed status text.
    @param sender The WebView sending the delegate method.
    @result The status text
*/
- (NSString *)webViewStatusText:(WebView *)sender;

/*!
    @method webViewAreToolbarsVisible:
    @abstract Determine whether the window's toolbars are currently visible
    @param sender The WebView sending the delegate method.
    @discussion This method should return YES if the window has any
    toolbars that are currently on, besides the status bar. If the app
    has more than one toolbar per window, for example a regular
    command toolbar and a favorites bar, it should return YES from
    this method if at least one is on.
    @result YES if at least one toolbar is visible, otherwise NO.
*/
- (BOOL)webViewAreToolbarsVisible:(WebView *)sender;

/*!
    @method webView:setToolbarsVisible:
    @param sender The WebView sending the delegate method.
    @abstract Set whether the window's toolbars are currently visible.
    @param visible New value for toolbar visibility
    @discussion Setting this to YES should turn on all toolbars
    (except for a possible status bar). Setting it to NO should turn
    off all toolbars (with the same exception).
*/
- (void)webView:(WebView *)sender setToolbarsVisible:(BOOL)visible;

/*!
    @method webViewIsStatusBarVisible:
    @abstract Determine whether the status bar is visible.
    @param sender The WebView sending the delegate method.
    @result YES if the status bar is visible, otherwise NO.
*/
- (BOOL)webViewIsStatusBarVisible:(WebView *)sender;

/*!
    @method webView:setStatusBarVisible:
    @abstract Set whether the status bar is currently visible.
    @param visible The new visibility value
    @discussion Setting this to YES should show the status bar,
    setting it to NO should hide it.
*/
- (void)webView:(WebView *)sender setStatusBarVisible:(BOOL)visible;

/*!
    @method webViewIsResizable:
    @abstract Determine whether the window is resizable or not.
    @param sender The WebView sending the delegate method.
    @result YES if resizable, NO if not.
    @discussion If there are multiple views in the same window, they
    have have their own separate resize controls and this may need to
    be handled specially.
*/
- (BOOL)webViewIsResizable:(WebView *)sender;

/*!
    @method webView:setResizable:
    @abstract Set the window to resizable or not
    @param sender The WebView sending the delegate method.
    @param resizable YES if the window should be made resizable, NO if not.
    @discussion If there are multiple views in the same window, they
    have have their own separate resize controls and this may need to
    be handled specially.
*/
- (void)webView:(WebView *)sender setResizable:(BOOL)resizable;

/*!
    @method webView:setFrame:
    @abstract Set the window's frame rect
    @param sender The WebView sending the delegate method.
    @param frame The new window frame size
    @discussion Even though a caller could set the frame directly using the NSWindow,
    this method is provided so implementors of this protocol can do special
    things on programmatic move/resize, like avoiding autosaving of the size.
*/
- (void)webView:(WebView *)sender setFrame:(NSRect)frame;

/*!
    @method webViewFrame:
    @param sender The WebView sending the delegate method.
    @abstract REturn the window's frame rect
    @discussion 
*/
- (NSRect)webViewFrame:(WebView *)sender;

/*!
    @method webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:
    @abstract Display a JavaScript alert panel.
    @param sender The WebView sending the delegate method.
    @param message The message to display.
    @param frame The WebFrame whose JavaScript initiated this call.
    @discussion Clients should visually indicate that this panel comes
    from JavaScript initiated by the specified frame. The panel should have 
    a single OK button.
*/
- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame;

/*!
    @method webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:
    @abstract Display a JavaScript confirm panel.
    @param sender The WebView sending the delegate method.
    @param message The message to display.
    @param frame The WebFrame whose JavaScript initiated this call.
    @result YES if the user hit OK, NO if the user chose Cancel.
    @discussion Clients should visually indicate that this panel comes
    from JavaScript initiated by the specified frame. The panel should have 
    two buttons, e.g. "OK" and "Cancel".
*/
- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame;

/*!
    @method webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:
    @abstract Display a JavaScript text input panel.
    @param sender The WebView sending the delegate method.
    @param message The message to display.
    @param defaultText The initial text for the text entry area.
    @param frame The WebFrame whose JavaScript initiated this call.
    @result The typed text if the user hit OK, otherwise nil.
    @discussion Clients should visually indicate that this panel comes
    from JavaScript initiated by the specified frame. The panel should have 
    two buttons, e.g. "OK" and "Cancel", and an area to type text.
*/
- (NSString *)webView:(WebView *)sender runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WebFrame *)frame;

/*!
    @method webView:runBeforeUnloadConfirmPanelWithMessage:initiatedByFrame:
    @abstract Display a confirm panel by an "before unload" event handler.
    @param sender The WebView sending the delegate method.
    @param message The message to display.
    @param frame The WebFrame whose JavaScript initiated this call.
    @result YES if the user hit OK, NO if the user chose Cancel.
    @discussion Clients should include a message in addition to the one
    supplied by the web page that indicates. The panel should have 
    two buttons, e.g. "OK" and "Cancel".
*/
- (BOOL)webView:(WebView *)sender runBeforeUnloadConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame;

/*!
    @method webView:runOpenPanelForFileButtonWithResultListener:
    @abstract Display a file open panel for a file input control.
    @param sender The WebView sending the delegate method.
    @param resultListener The object to call back with the results.
    @discussion This method is passed a callback object instead of giving a return
    value so that it can be handled with a sheet.
*/
- (void)webView:(WebView *)sender runOpenPanelForFileButtonWithResultListener:(id<WebOpenPanelResultListener>)resultListener;

/*!
    @method webView:runOpenPanelForFileButtonWithResultListener:allowMultipleFiles
    @abstract Display a file open panel for a file input control that may allow multiple files to be selected.
    @param sender The WebView sending the delegate method.
    @param resultListener The object to call back with the results.
    @param allowMultipleFiles YES if the open panel should allow myltiple files to be selected, NO if not.
    @discussion This method is passed a callback object instead of giving a return
    value so that it can be handled with a sheet.
*/
- (void)webView:(WebView *)sender runOpenPanelForFileButtonWithResultListener:(id<WebOpenPanelResultListener>)resultListener allowMultipleFiles:(BOOL)allowMultipleFiles WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_IN_WEBKIT_VERSION_4_0);

/*!
    @method webView:mouseDidMoveOverElement:modifierFlags:
    @abstract Update the window's feedback for mousing over links to reflect a new item the mouse is over
    or new modifier flags.
    @param sender The WebView sending the delegate method.
    @param elementInformation Dictionary that describes the element that the mouse is over, or nil.
    @param modifierFlags The modifier flags as in NSEvent.
*/
- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags;

/*!
    @method webView:contextMenuItemsForElement:defaultMenuItems:
    @abstract Returns the menu items to display in an element's contextual menu.
    @param sender The WebView sending the delegate method.
    @param element A dictionary representation of the clicked element.
    @param defaultMenuItems An array of default NSMenuItems to include in all contextual menus.
    @result An array of NSMenuItems to include in the contextual menu.
*/
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;

/*!
    @method webView:validateUserInterfaceItem:defaultValidation:
    @abstract Controls UI validation
    @param webView The WebView sending the delegate method
    @param item The user interface item being validated
    @pararm defaultValidation Whether or not the WebView thinks the item is valid
    @discussion This method allows the UI delegate to control WebView's validation of user interface items.
    See WebView.h to see the methods to that WebView can currently validate. See NSUserInterfaceValidations and
    NSValidatedUserInterfaceItem for information about UI validation.
*/
- (BOOL)webView:(WebView *)webView validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item defaultValidation:(BOOL)defaultValidation;

/*!
    @method webView:shouldPerformAction:fromSender:
    @abstract Controls actions
    @param webView The WebView sending the delegate method
    @param action The action being sent
    @param sender The sender of the action
    @discussion This method allows the UI delegate to control WebView's behavior when an action is being sent.
    For example, if the action is copy:, the delegate can return YES to allow WebView to perform its default
    copy behavior or return NO and perform copy: in some other way. See WebView.h to see the actions that
    WebView can perform.
*/
- (BOOL)webView:(WebView *)webView shouldPerformAction:(SEL)action fromSender:(id)sender;

/*!
    @method webView:dragDestinationActionMaskForDraggingInfo:
    @abstract Controls behavior when dragging to a WebView
    @param webView The WebView sending the delegate method
    @param draggingInfo The dragging info of the drag
    @discussion This method is called periodically as something is dragged over a WebView. The UI delegate can return a mask
    indicating which drag destination actions can occur, WebDragDestinationActionAny to allow any kind of action or
    WebDragDestinationActionNone to not accept the drag.
*/
- (NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo;

/*!
    @method webView:willPerformDragDestinationAction:forDraggingInfo:
    @abstract Informs that WebView will perform a drag destination action
    @param webView The WebView sending the delegate method
    @param action The drag destination action
    @param draggingInfo The dragging info of the drag
    @discussion This method is called after the last call to webView:dragDestinationActionMaskForDraggingInfo: after something is dropped on a WebView.
    This method informs the UI delegate of the drag destination action that WebView will perform.
*/
- (void)webView:(WebView *)webView willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id <NSDraggingInfo>)draggingInfo;

/*!
    @method webView:dragSourceActionMaskForPoint:
    @abstract Controls behavior when dragging from a WebView
    @param webView The WebView sending the delegate method
    @param point The point where the drag started in the coordinates of the WebView
    @discussion This method is called after the user has begun a drag from a WebView. The UI delegate can return a mask indicating
    which drag source actions can occur, WebDragSourceActionAny to allow any kind of action or WebDragSourceActionNone to not begin a drag.
*/
- (NSUInteger)webView:(WebView *)webView dragSourceActionMaskForPoint:(NSPoint)point;

/*!
    @method webView:willPerformDragSourceAction:fromPoint:withPasteboard:
    @abstract Informs that a drag a has begun from a WebView
    @param webView The WebView sending the delegate method
    @param action The drag source action
    @param point The point where the drag started in the coordinates of the WebView
    @param pasteboard The drag pasteboard
    @discussion This method is called after webView:dragSourceActionMaskForPoint: is called after the user has begun a drag from a WebView.
    This method informs the UI delegate of the drag source action that will be performed and gives the delegate an opportunity to modify
    the contents of the dragging pasteboard.
*/
- (void)webView:(WebView *)webView willPerformDragSourceAction:(WebDragSourceAction)action fromPoint:(NSPoint)point withPasteboard:(NSPasteboard *)pasteboard;

/*!
    @method webView:printFrameView:
    @abstract Informs that a WebFrameView needs to be printed
    @param webView The WebView sending the delegate method
    @param frameView The WebFrameView needing to be printed
    @discussion This method is called when a script or user requests the page to be printed.
    In this method the delegate can prepare the WebFrameView to be printed. Some content that WebKit
    displays can be printed directly by the WebFrameView, other content will need to be handled by
    the delegate. To determine if the WebFrameView can handle printing the delegate should check
    WebFrameView's documentViewShouldHandlePrint, if YES then the delegate can call printDocumentView
    on the WebFrameView. Otherwise the delegate will need to request a NSPrintOperation from
    the WebFrameView's printOperationWithPrintInfo to handle the printing.
*/
- (void)webView:(WebView *)sender printFrameView:(WebFrameView *)frameView;

/*!
    @method webViewHeaderHeight:
    @param webView The WebView sending the delegate method
    @abstract Reserve a height for the printed page header.
    @result The height to reserve for the printed page header, return 0.0 to not reserve any space for a header.
    @discussion The height returned will be used to calculate the rect passed to webView:drawHeaderInRect:.
*/
- (float)webViewHeaderHeight:(WebView *)sender;

/*!
    @method webViewFooterHeight:
    @param webView The WebView sending the delegate method
    @abstract Reserve a height for the printed page footer.
    @result The height to reserve for the printed page footer, return 0.0 to not reserve any space for a footer.
    @discussion The height returned will be used to calculate the rect passed to webView:drawFooterInRect:.
*/
- (float)webViewFooterHeight:(WebView *)sender;

/*!
    @method webView:drawHeaderInRect:
    @param webView The WebView sending the delegate method
    @param rect The NSRect reserved for the header of the page
    @abstract The delegate should draw a header for the sender in the supplied rect.
*/
- (void)webView:(WebView *)sender drawHeaderInRect:(NSRect)rect;

/*!
    @method webView:drawFooterInRect:
    @param webView The WebView sending the delegate method
    @param rect The NSRect reserved for the footer of the page
    @abstract The delegate should draw a footer for the sender in the supplied rect.
*/
- (void)webView:(WebView *)sender drawFooterInRect:(NSRect)rect;

// The following delegate methods are deprecated in favor of the ones above that specify
// the WebFrame whose JavaScript initiated this call.
- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_WEBKIT_VERSION_1_0_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0);
- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_WEBKIT_VERSION_1_0_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0);
- (NSString *)webView:(WebView *)sender runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_WEBKIT_VERSION_1_0_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0);

// The following delegate methods are deprecated. Content rect calculations are now done automatically.
- (void)webView:(WebView *)sender setContentRect:(NSRect)frame WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_WEBKIT_VERSION_1_0_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0);
- (NSRect)webViewContentRect:(WebView *)sender WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_WEBKIT_VERSION_1_0_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0);

@end
