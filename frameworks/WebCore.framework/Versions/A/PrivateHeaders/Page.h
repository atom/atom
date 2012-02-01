/*
 * Copyright (C) 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2008 Torch Mobile Inc. All rights reserved. (http://www.torchmobile.com/)
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

#ifndef Page_h
#define Page_h

#include "FrameLoaderTypes.h"
#include "FindOptions.h"
#include "LayoutTypes.h"
#include "PageVisibilityState.h"
#include "PlatformScreen.h"
#include "PlatformString.h"
#include "ViewportArguments.h"
#include <wtf/Forward.h>
#include <wtf/HashSet.h>
#include <wtf/Noncopyable.h>

#if OS(SOLARIS)
#include <sys/time.h> // For time_t structure.
#endif

#if PLATFORM(MAC)
#include "SchedulePair.h"
#endif

namespace JSC {
    class Debugger;
}

namespace WebCore {

    class BackForwardController;
    class BackForwardList;
    class Chrome;
    class ChromeClient;
    class ContextMenuClient;
    class ContextMenuController;
    class DeviceMotionClient;
    class DeviceMotionController;
    class DeviceOrientationClient;
    class DeviceOrientationController;
    class Document;
    class DragCaretController;
    class DragClient;
    class DragController;
    class EditorClient;
    class FocusController;
    class Frame;
    class FrameSelection;
    class GeolocationClient;
    class GeolocationController;
    class HaltablePlugin;
    class HistoryItem;
    class InspectorClient;
    class InspectorController;
    class MediaCanStartListener;
    class Node;
    class NotificationController;
    class NotificationPresenter;
    class PageGroup;
    class PluginData;
    class ProgressTracker;
    class Range;
    class RenderTheme;
    class VisibleSelection;
    class ScrollableArea;
    class ScrollingCoordinator;
    class Settings;
    class SpeechInput;
    class SpeechInputClient;
    class UserMediaClient;
    class StorageNamespace;
#if ENABLE(NOTIFICATIONS)
    class NotificationPresenter;
#endif

    typedef uint64_t LinkHash;

    enum FindDirection { FindDirectionForward, FindDirectionBackward };

    float deviceScaleFactor(Frame*);

    class Page {
        WTF_MAKE_NONCOPYABLE(Page);
        friend class Settings;
    public:
        static void scheduleForcedStyleRecalcForAllPages();

        // It is up to the platform to ensure that non-null clients are provided where required.
        struct PageClients {
            WTF_MAKE_NONCOPYABLE(PageClients); WTF_MAKE_FAST_ALLOCATED;
        public:
            PageClients();
            ~PageClients();

            ChromeClient* chromeClient;
            ContextMenuClient* contextMenuClient;
            EditorClient* editorClient;
            DragClient* dragClient;
            InspectorClient* inspectorClient;
            GeolocationClient* geolocationClient;
            DeviceMotionClient* deviceMotionClient;
            DeviceOrientationClient* deviceOrientationClient;
            RefPtr<BackForwardList> backForwardClient;
            SpeechInputClient* speechInputClient;
            NotificationPresenter* notificationClient;
            UserMediaClient* userMediaClient;
        };

        Page(PageClients&);
        ~Page();

        void setNeedsRecalcStyleInAllFrames();

        RenderTheme* theme() const { return m_theme.get(); };

        ViewportArguments viewportArguments() const { return m_viewportArguments; }
        void updateViewportArguments();

        static void refreshPlugins(bool reload);
        PluginData* pluginData() const;

        void setCanStartMedia(bool);
        bool canStartMedia() const { return m_canStartMedia; }

        EditorClient* editorClient() const { return m_editorClient; }

        void setMainFrame(PassRefPtr<Frame>);
        Frame* mainFrame() const { return m_mainFrame.get(); }

        bool openedByDOM() const;
        void setOpenedByDOM();

        // DEPRECATED. Use backForward() instead of the following 6 functions.
        BackForwardList* backForwardList() const;
        bool goBack();
        bool goForward();
        bool canGoBackOrForward(int distance) const;
        void goBackOrForward(int distance);
        int getHistoryLength();

        void goToItem(HistoryItem*, FrameLoadType);

        void setGroupName(const String&);
        const String& groupName() const;

        PageGroup& group() { if (!m_group) initGroup(); return *m_group; }
        PageGroup* groupPtr() { return m_group; } // can return 0

        void incrementFrameCount() { ++m_frameCount; }
        void decrementFrameCount() { ASSERT(m_frameCount); --m_frameCount; }
        int frameCount() const { checkFrameCountConsistency(); return m_frameCount; }

        Chrome* chrome() const { return m_chrome.get(); }
        DragCaretController* dragCaretController() const { return m_dragCaretController.get(); }
#if ENABLE(DRAG_SUPPORT)
        DragController* dragController() const { return m_dragController.get(); }
#endif
        FocusController* focusController() const { return m_focusController.get(); }
#if ENABLE(CONTEXT_MENUS)
        ContextMenuController* contextMenuController() const { return m_contextMenuController.get(); }
#endif
#if ENABLE(INSPECTOR)
        InspectorController* inspectorController() const { return m_inspectorController.get(); }
#endif
#if ENABLE(CLIENT_BASED_GEOLOCATION)
        GeolocationController* geolocationController() const { return m_geolocationController.get(); }
#endif
#if ENABLE(DEVICE_ORIENTATION)
        DeviceMotionController* deviceMotionController() const { return m_deviceMotionController.get(); }
        DeviceOrientationController* deviceOrientationController() const { return m_deviceOrientationController.get(); }
#endif
#if ENABLE(NOTIFICATIONS)
        NotificationController* notificationController() const { return m_notificationController.get(); }
#endif
#if ENABLE(INPUT_SPEECH)
        SpeechInput* speechInput();
#endif
#if ENABLE(MEDIA_STREAM)
        UserMediaClient* userMediaClient() const { return m_userMediaClient; }
#endif
#if ENABLE(THREADED_SCROLLING)
        ScrollingCoordinator* scrollingCoordinator();
#endif

        Settings* settings() const { return m_settings.get(); }
        ProgressTracker* progress() const { return m_progress.get(); }
        BackForwardController* backForward() const { return m_backForwardController.get(); }

        enum ViewMode {
            ViewModeInvalid,
            ViewModeWindowed,
            ViewModeFloating,
            ViewModeFullscreen,
            ViewModeMaximized,
            ViewModeMinimized
        };
        static ViewMode stringToViewMode(const String&);

        ViewMode viewMode() const { return m_viewMode; }
        void setViewMode(ViewMode);
        
        void setTabKeyCyclesThroughElements(bool b) { m_tabKeyCyclesThroughElements = b; }
        bool tabKeyCyclesThroughElements() const { return m_tabKeyCyclesThroughElements; }

        bool findString(const String&, FindOptions);
        // FIXME: Switch callers over to the FindOptions version and retire this one.
        bool findString(const String&, TextCaseSensitivity, FindDirection, bool shouldWrap);

        PassRefPtr<Range> rangeOfString(const String&, Range*, FindOptions);

        unsigned markAllMatchesForText(const String&, FindOptions, bool shouldHighlight, unsigned);
        // FIXME: Switch callers over to the FindOptions version and retire this one.
        unsigned markAllMatchesForText(const String&, TextCaseSensitivity, bool shouldHighlight, unsigned);
        void unmarkAllTextMatches();

#if PLATFORM(MAC)
        void addSchedulePair(PassRefPtr<SchedulePair>);
        void removeSchedulePair(PassRefPtr<SchedulePair>);
        SchedulePairHashSet* scheduledRunLoopPairs() { return m_scheduledRunLoopPairs.get(); }

        OwnPtr<SchedulePairHashSet> m_scheduledRunLoopPairs;
#endif

        const VisibleSelection& selection() const;

        void setDefersLoading(bool);
        bool defersLoading() const { return m_defersLoading; }
        
        void clearUndoRedoOperations();

        bool inLowQualityImageInterpolationMode() const;
        void setInLowQualityImageInterpolationMode(bool = true);

        bool cookieEnabled() const { return m_cookieEnabled; }
        void setCookieEnabled(bool enabled) { m_cookieEnabled = enabled; }

        float mediaVolume() const { return m_mediaVolume; }
        void setMediaVolume(float volume);

        void setPageScaleFactor(float scale, const IntPoint& origin);
        float pageScaleFactor() const { return m_pageScaleFactor; }

        float deviceScaleFactor() const { return m_deviceScaleFactor; }
        void setDeviceScaleFactor(float);

        struct Pagination {
            enum Mode { Unpaginated, HorizontallyPaginated, VerticallyPaginated };

            Pagination()
                : mode(Unpaginated)
                , pageLength(0)
                , gap(0)
            {
            };

            bool operator==(const Pagination& other) const
            {
                return mode == other.mode && pageLength == other.pageLength && gap == other.gap;
            }

            Mode mode;
            unsigned pageLength;
            unsigned gap;
        };

        const Pagination& pagination() const { return m_pagination; }
        void setPagination(const Pagination&);

        unsigned pageCount() const;

        // Notifications when the Page starts and stops being presented via a native window.
        void didMoveOnscreen();
        void willMoveOffscreen();

        void windowScreenDidChange(PlatformDisplayID);
        
        void suspendScriptedAnimations();
        void resumeScriptedAnimations();
        
        void userStyleSheetLocationChanged();
        const String& userStyleSheet() const;

        void dnsPrefetchingStateChanged();
        void privateBrowsingStateChanged();

        static void setDebuggerForAllPages(JSC::Debugger*);
        void setDebugger(JSC::Debugger*);
        JSC::Debugger* debugger() const { return m_debugger; }

        static void removeAllVisitedLinks();

        static void allVisitedStateChanged(PageGroup*);
        static void visitedStateChanged(PageGroup*, LinkHash visitedHash);

        StorageNamespace* sessionStorage(bool optionalCreate = true);
        void setSessionStorage(PassRefPtr<StorageNamespace>);

        void setCustomHTMLTokenizerTimeDelay(double);
        bool hasCustomHTMLTokenizerTimeDelay() const { return m_customHTMLTokenizerTimeDelay != -1; }
        double customHTMLTokenizerTimeDelay() const { ASSERT(m_customHTMLTokenizerTimeDelay != -1); return m_customHTMLTokenizerTimeDelay; }

        void setCustomHTMLTokenizerChunkSize(int);
        bool hasCustomHTMLTokenizerChunkSize() const { return m_customHTMLTokenizerChunkSize != -1; }
        int customHTMLTokenizerChunkSize() const { ASSERT(m_customHTMLTokenizerChunkSize != -1); return m_customHTMLTokenizerChunkSize; }

        void setMemoryCacheClientCallsEnabled(bool);
        bool areMemoryCacheClientCallsEnabled() const { return m_areMemoryCacheClientCallsEnabled; }

        void setJavaScriptURLsAreAllowed(bool);
        bool javaScriptURLsAreAllowed() const;

        typedef HashSet<ScrollableArea*> ScrollableAreaSet;
        void addScrollableArea(ScrollableArea*);
        void removeScrollableArea(ScrollableArea*);
        bool containsScrollableArea(ScrollableArea*) const;
        const ScrollableAreaSet* scrollableAreaSet() const { return m_scrollableAreaSet.get(); }

        // Don't allow more than a certain number of frames in a page.
        // This seems like a reasonable upper bound, and otherwise mutually
        // recursive frameset pages can quickly bring the program to its knees
        // with exponential growth in the number of frames.
        static const int maxNumberOfFrames = 1000;

        void setEditable(bool isEditable) { m_isEditable = isEditable; }
        bool isEditable() { return m_isEditable; }

#if ENABLE(PAGE_VISIBILITY_API)
        PageVisibilityState visibilityState() const;
        void setVisibilityState(PageVisibilityState, bool);
#endif

        PlatformDisplayID displayID() const { return m_displayID; }
        
    private:
        void initGroup();

#if ASSERT_DISABLED
        void checkFrameCountConsistency() const { }
#else
        void checkFrameCountConsistency() const;
#endif

        MediaCanStartListener* takeAnyMediaCanStartListener();

        void setMinimumTimerInterval(double);
        double minimumTimerInterval() const;

        OwnPtr<Chrome> m_chrome;
        OwnPtr<DragCaretController> m_dragCaretController;

#if ENABLE(DRAG_SUPPORT)
        OwnPtr<DragController> m_dragController;
#endif
        OwnPtr<FocusController> m_focusController;
#if ENABLE(CONTEXT_MENUS)
        OwnPtr<ContextMenuController> m_contextMenuController;
#endif
#if ENABLE(INSPECTOR)
        OwnPtr<InspectorController> m_inspectorController;
#endif
#if ENABLE(CLIENT_BASED_GEOLOCATION)
        OwnPtr<GeolocationController> m_geolocationController;
#endif
#if ENABLE(DEVICE_ORIENTATION)
        OwnPtr<DeviceMotionController> m_deviceMotionController;
        OwnPtr<DeviceOrientationController> m_deviceOrientationController;
#endif
#if ENABLE(NOTIFICATIONS)
        OwnPtr<NotificationController> m_notificationController;
#endif
#if ENABLE(INPUT_SPEECH)
        SpeechInputClient* m_speechInputClient;
        OwnPtr<SpeechInput> m_speechInput;
#endif
#if ENABLE(MEDIA_STREAM)
        UserMediaClient* m_userMediaClient;
#endif
#if ENABLE(THREADED_SCROLLING)
        RefPtr<ScrollingCoordinator> m_scrollingCoordinator;
#endif
        OwnPtr<Settings> m_settings;
        OwnPtr<ProgressTracker> m_progress;
        
        OwnPtr<BackForwardController> m_backForwardController;
        RefPtr<Frame> m_mainFrame;

        mutable RefPtr<PluginData> m_pluginData;

        RefPtr<RenderTheme> m_theme;

        EditorClient* m_editorClient;

        int m_frameCount;
        String m_groupName;
        bool m_openedByDOM;

        bool m_tabKeyCyclesThroughElements;
        bool m_defersLoading;

        bool m_inLowQualityInterpolationMode;
        bool m_cookieEnabled;
        bool m_areMemoryCacheClientCallsEnabled;
        float m_mediaVolume;

        float m_pageScaleFactor;
        float m_deviceScaleFactor;

        Pagination m_pagination;

        bool m_javaScriptURLsAreAllowed;

        String m_userStyleSheetPath;
        mutable String m_userStyleSheet;
        mutable bool m_didLoadUserStyleSheet;
        mutable time_t m_userStyleSheetModificationTime;

        OwnPtr<PageGroup> m_singlePageGroup;
        PageGroup* m_group;

        JSC::Debugger* m_debugger;

        double m_customHTMLTokenizerTimeDelay;
        int m_customHTMLTokenizerChunkSize;

        bool m_canStartMedia;

        RefPtr<StorageNamespace> m_sessionStorage;

#if ENABLE(NOTIFICATIONS)
        NotificationPresenter* m_notificationPresenter;
#endif

        ViewMode m_viewMode;

        ViewportArguments m_viewportArguments;

        double m_minimumTimerInterval;

        OwnPtr<ScrollableAreaSet> m_scrollableAreaSet;

        bool m_isEditable;

#if ENABLE(PAGE_VISIBILITY_API)
        PageVisibilityState m_visibilityState;
#endif
        PlatformDisplayID m_displayID;
    };

} // namespace WebCore
    
#endif // Page_h
