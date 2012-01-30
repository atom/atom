/*
 * Copyright (C) 2006, 2007, 2008, 2009 Apple, Inc. All rights reserved.
 * Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies).
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#ifndef ChromeClient_h
#define ChromeClient_h

#include "AXObjectCache.h"
#include "ConsoleTypes.h"
#include "Cursor.h"
#include "FocusDirection.h"
#include "FrameLoader.h"
#include "GraphicsContext.h"
#include "HostWindow.h"
#include "PopupMenu.h"
#include "PopupMenuClient.h"
#include "ScrollTypes.h"
#include "SearchPopupMenu.h"
#include "WebCoreKeyboardUIMode.h"
#include <wtf/Forward.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/UnusedParam.h>
#include <wtf/Vector.h>

#ifndef __OBJC__
class NSMenu;
class NSResponder;
#endif

namespace WebCore {

    class AccessibilityObject;
    class Element;
    class FileChooser;
    class FileIconLoader;
    class FloatRect;
    class Frame;
    class Geolocation;
    class GraphicsLayer;
    class HitTestResult;
    class IntRect;
    class NavigationAction;
    class Node;
    class Page;
    class PopupMenuClient;
    class SecurityOrigin;
    class GraphicsContext3D;
    class Widget;

    struct FrameLoadRequest;
    struct ViewportArguments;
    struct WindowFeatures;

#if USE(ACCELERATED_COMPOSITING)
    class GraphicsLayer;
#endif

#if ENABLE(INPUT_COLOR)
    class ColorChooser;
    class ColorChooserClient;
#endif

    class ChromeClient {
    public:
        virtual void chromeDestroyed() = 0;
        
        virtual void setWindowRect(const FloatRect&) = 0;
        virtual FloatRect windowRect() = 0;
        
        virtual FloatRect pageRect() = 0;
        
        virtual void focus() = 0;
        virtual void unfocus() = 0;

        virtual bool canTakeFocus(FocusDirection) = 0;
        virtual void takeFocus(FocusDirection) = 0;

        virtual void focusedNodeChanged(Node*) = 0;
        virtual void focusedFrameChanged(Frame*) = 0;

        // The Frame pointer provides the ChromeClient with context about which
        // Frame wants to create the new Page.  Also, the newly created window
        // should not be shown to the user until the ChromeClient of the newly
        // created Page has its show method called.
        // The FrameLoadRequest parameter is only for ChromeClient to check if the
        // request could be fulfilled.  The ChromeClient should not load the request.
        virtual Page* createWindow(Frame*, const FrameLoadRequest&, const WindowFeatures&, const NavigationAction&) = 0;
        virtual void show() = 0;

        virtual bool canRunModal() = 0;
        virtual void runModal() = 0;

        virtual void setToolbarsVisible(bool) = 0;
        virtual bool toolbarsVisible() = 0;
        
        virtual void setStatusbarVisible(bool) = 0;
        virtual bool statusbarVisible() = 0;
        
        virtual void setScrollbarsVisible(bool) = 0;
        virtual bool scrollbarsVisible() = 0;
        
        virtual void setMenubarVisible(bool) = 0;
        virtual bool menubarVisible() = 0;

        virtual void setResizable(bool) = 0;
        
        virtual void addMessageToConsole(MessageSource, MessageType, MessageLevel, const String& message, unsigned int lineNumber, const String& sourceID) = 0;

        virtual bool canRunBeforeUnloadConfirmPanel() = 0;
        virtual bool runBeforeUnloadConfirmPanel(const String& message, Frame* frame) = 0;

        virtual void closeWindowSoon() = 0;
        
        virtual void runJavaScriptAlert(Frame*, const String&) = 0;
        virtual bool runJavaScriptConfirm(Frame*, const String&) = 0;
        virtual bool runJavaScriptPrompt(Frame*, const String& message, const String& defaultValue, String& result) = 0;
        virtual void setStatusbarText(const String&) = 0;
        virtual bool shouldInterruptJavaScript() = 0;
        virtual KeyboardUIMode keyboardUIMode() = 0;

        virtual void* webView() const = 0;

#if ENABLE(REGISTER_PROTOCOL_HANDLER)
        virtual void registerProtocolHandler(const String& scheme, const String& baseURL, const String& url, const String& title) = 0;
#endif

        virtual IntRect windowResizerRect() const = 0;

        // Methods used by HostWindow.
        virtual void invalidateRootView(const IntRect&, bool) = 0;
        virtual void invalidateContentsAndRootView(const IntRect&, bool) = 0;
        virtual void invalidateContentsForSlowScroll(const IntRect&, bool) = 0;
        virtual void scroll(const IntSize&, const IntRect&, const IntRect&) = 0;
#if USE(TILED_BACKING_STORE)
        virtual void delegatedScrollRequested(const IntPoint&) = 0;
#endif
        virtual IntPoint screenToRootView(const IntPoint&) const = 0;
        virtual IntRect rootViewToScreen(const IntRect&) const = 0;
        virtual PlatformPageClient platformPageClient() const = 0;
        virtual void scrollbarsModeDidChange() const = 0;
        virtual void setCursor(const Cursor&) = 0;
        virtual void setCursorHiddenUntilMouseMoves(bool) = 0;
#if ENABLE(REQUEST_ANIMATION_FRAME) && !USE(REQUEST_ANIMATION_FRAME_TIMER)
        virtual void scheduleAnimation() = 0;
#endif
        // End methods used by HostWindow.

        virtual void dispatchViewportPropertiesDidChange(const ViewportArguments&) const { }

        virtual void contentsSizeChanged(Frame*, const IntSize&) const = 0;
        virtual void layoutUpdated(Frame*) const { }
        virtual void scrollRectIntoView(const IntRect&) const { }; // Currently only Mac has a non empty implementation.
       
        virtual bool shouldMissingPluginMessageBeButton() const { return false; }
        virtual void missingPluginButtonClicked(Element*) const { }
        virtual void mouseDidMoveOverElement(const HitTestResult&, unsigned modifierFlags) = 0;

        virtual void setToolTip(const String&, TextDirection) = 0;

        virtual void print(Frame*) = 0;
        virtual bool shouldRubberBandInDirection(ScrollDirection) const = 0;

#if ENABLE(SQL_DATABASE)
        virtual void exceededDatabaseQuota(Frame*, const String& databaseName) = 0;
#endif

        // Callback invoked when the application cache fails to save a cache object
        // because storing it would grow the database file past its defined maximum
        // size or past the amount of free space on the device. 
        // The chrome client would need to take some action such as evicting some
        // old caches.
        virtual void reachedMaxAppCacheSize(int64_t spaceNeeded) = 0;

        // Callback invoked when the application cache origin quota is reached. This
        // means that the resources attempting to be cached via the manifest are
        // more than allowed on this origin. This callback allows the chrome client
        // to take action, such as prompting the user to ask to increase the quota
        // for this origin. The totalSpaceNeeded parameter is the total amount of
        // storage, in bytes, needed to store the new cache along with all of the
        // other existing caches for the origin that would not be replaced by
        // the new cache.
        virtual void reachedApplicationCacheOriginQuota(SecurityOrigin*, int64_t totalSpaceNeeded) = 0;

#if ENABLE(DASHBOARD_SUPPORT)
        virtual void dashboardRegionsChanged();
#endif

        virtual void populateVisitedLinks();

        virtual FloatRect customHighlightRect(Node*, const AtomicString& type, const FloatRect& lineRect);
        virtual void paintCustomHighlight(Node*, const AtomicString& type, const FloatRect& boxRect, const FloatRect& lineRect,
            bool behindText, bool entireLine);
            
        virtual bool shouldReplaceWithGeneratedFileForUpload(const String& path, String& generatedFilename);
        virtual String generateReplacementFile(const String& path);

        virtual bool paintCustomOverhangArea(GraphicsContext*, const IntRect&, const IntRect&, const IntRect&);

        // FIXME: Remove once all ports are using client-based geolocation. https://bugs.webkit.org/show_bug.cgi?id=40373
        // For client-based geolocation, these two methods have moved to GeolocationClient. https://bugs.webkit.org/show_bug.cgi?id=50061
        // This can be either a synchronous or asynchronous call. The ChromeClient can display UI asking the user for permission
        // to use Geolocation.
        virtual void requestGeolocationPermissionForFrame(Frame*, Geolocation*) = 0;
        virtual void cancelGeolocationPermissionRequestForFrame(Frame*, Geolocation*) = 0;

#if ENABLE(INPUT_COLOR)
        virtual PassOwnPtr<ColorChooser> createColorChooser(ColorChooserClient*, const Color&) = 0;
#endif

        virtual void runOpenPanel(Frame*, PassRefPtr<FileChooser>) = 0;
        // Asynchronous request to load an icon for specified filenames.
        virtual void loadIconForFiles(const Vector<String>&, FileIconLoader*) = 0;

#if ENABLE(DIRECTORY_UPLOAD)
        // Asychronous request to enumerate all files in a directory chosen by the user.
        virtual void enumerateChosenDirectory(FileChooser*) = 0;
#endif

        // Notification that the given form element has changed. This function
        // will be called frequently, so handling should be very fast.
        virtual void formStateDidChange(const Node*) = 0;
        
        virtual void elementDidFocus(const Node*) { };
        virtual void elementDidBlur(const Node*) { };

#if USE(ACCELERATED_COMPOSITING)
        // Pass 0 as the GraphicsLayer to detatch the root layer.
        virtual void attachRootGraphicsLayer(Frame*, GraphicsLayer*) = 0;
        // Sets a flag to specify that the next time content is drawn to the window,
        // the changes appear on the screen in synchrony with updates to GraphicsLayers.
        virtual void setNeedsOneShotDrawingSynchronization() = 0;
        // Sets a flag to specify that the view needs to be updated, so we need
        // to do an eager layout before the drawing.
        virtual void scheduleCompositingLayerSync() = 0;
        // Returns whether or not the client can render the composited layer,
        // regardless of the settings.
        virtual bool allowsAcceleratedCompositing() const { return true; }

        enum CompositingTrigger {
            ThreeDTransformTrigger = 1 << 0,
            VideoTrigger = 1 << 1,
            PluginTrigger = 1 << 2,
            CanvasTrigger = 1 << 3,
            AnimationTrigger = 1 << 4,
            FilterTrigger = 1 << 5,
            AllTriggers = 0xFFFFFFFF
        };
        typedef unsigned CompositingTriggerFlags;

        // Returns a bitfield indicating conditions that can trigger the compositor.
        virtual CompositingTriggerFlags allowedCompositingTriggers() const { return static_cast<CompositingTriggerFlags>(AllTriggers); }
#endif

        virtual bool supportsFullscreenForNode(const Node*) { return false; }
        virtual void enterFullscreenForNode(Node*) { }
        virtual void exitFullscreenForNode(Node*) { }
        virtual bool requiresFullscreenForVideoPlayback() { return false; } 

#if ENABLE(FULLSCREEN_API)
        virtual bool supportsFullScreenForElement(const Element*, bool) { return false; }
        virtual void enterFullScreenForElement(Element*) { }
        virtual void exitFullScreenForElement(Element*) { }
        virtual void fullScreenRendererChanged(RenderBox*) { }
        virtual void setRootFullScreenLayer(GraphicsLayer*) { }
#endif
        
#if USE(TILED_BACKING_STORE)
        virtual IntRect visibleRectForTiledBackingStore() const { return IntRect(); }
#endif

#if PLATFORM(MAC)
        virtual NSResponder *firstResponder() { return 0; }
        virtual void makeFirstResponder(NSResponder *) { }
        // Focuses on the containing view associated with this page.
        virtual void makeFirstResponder() { }
        virtual void willPopUpMenu(NSMenu *) { }
#endif

#if PLATFORM(WIN)
        virtual void setLastSetCursorToCurrentCursor() = 0;
#endif

#if ENABLE(TOUCH_EVENTS)
        virtual void needTouchEvents(bool) = 0;
#endif

        virtual bool selectItemWritingDirectionIsNatural() = 0;
        virtual bool selectItemAlignmentFollowsMenuWritingDirection() = 0;
        // Checks if there is an opened popup, called by RenderMenuList::showPopup().
        virtual bool hasOpenedPopup() const = 0;
        virtual PassRefPtr<PopupMenu> createPopupMenu(PopupMenuClient*) const = 0;
        virtual PassRefPtr<SearchPopupMenu> createSearchPopupMenu(PopupMenuClient*) const = 0;

#if ENABLE(CONTEXT_MENUS)
        virtual void showContextMenu() = 0;
#endif

        virtual void postAccessibilityNotification(AccessibilityObject*, AXObjectCache::AXNotification) { }
        
        virtual void notifyScrollerThumbIsVisibleInRect(const IntRect&) { }
        virtual void recommendedScrollbarStyleDidChange(int /*newStyle*/) { }

        enum DialogType {
            AlertDialog = 0,
            ConfirmDialog = 1,
            PromptDialog = 2,
            HTMLDialog = 3
        };
        virtual bool shouldRunModalDialogDuringPageDismissal(const DialogType&, const String& dialogMessage, FrameLoader::PageDismissalType) const { UNUSED_PARAM(dialogMessage); return true; }

        virtual void numWheelEventHandlersChanged(unsigned) = 0;
        
        virtual bool isSVGImageChromeClient() const { return false; }

    protected:
        virtual ~ChromeClient() { }
    };

}

#endif // ChromeClient_h
