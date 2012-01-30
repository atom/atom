/*
 * Copyright (C) 2003, 2006, 2007, 2008, 2009, 2011 Apple Inc. All rights reserved.
 *           (C) 2006 Graham Dennis (graham.dennis@gmail.com)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef Settings_h
#define Settings_h

#include "EditingBehaviorTypes.h"
#include "FontRenderingMode.h"
#include "KURL.h"
#include "Timer.h"
#include <wtf/HashMap.h>
#include <wtf/text/AtomicString.h>
#include <wtf/text/AtomicStringHash.h>
#include <wtf/unicode/Unicode.h>

namespace WebCore {

    class Page;

    enum EditableLinkBehavior {
        EditableLinkDefaultBehavior,
        EditableLinkAlwaysLive,
        EditableLinkOnlyLiveWithShiftKey,
        EditableLinkLiveWhenNotFocused,
        EditableLinkNeverLive
    };

    enum TextDirectionSubmenuInclusionBehavior {
        TextDirectionSubmenuNeverIncluded,
        TextDirectionSubmenuAutomaticallyIncluded,
        TextDirectionSubmenuAlwaysIncluded
    };

    // UScriptCode uses -1 and 0 for UScriptInvalidCode and UScriptCommon.
    // We need to use -2 and -3 for empty value and deleted value.
    struct UScriptCodeHashTraits : WTF::GenericHashTraits<int> {
        static const bool emptyValueIsZero = false;
        static int emptyValue() { return -2; }
        static void constructDeletedValue(int& slot) { slot = -3; }
        static bool isDeletedValue(int value) { return value == -3; }
    };

    typedef HashMap<int, AtomicString, DefaultHash<int>::Hash, UScriptCodeHashTraits> ScriptFontFamilyMap;

    class Settings {
        WTF_MAKE_NONCOPYABLE(Settings); WTF_MAKE_FAST_ALLOCATED;
    public:
        static PassOwnPtr<Settings> create(Page*);

        void setStandardFontFamily(const AtomicString&, UScriptCode = USCRIPT_COMMON);
        const AtomicString& standardFontFamily(UScriptCode = USCRIPT_COMMON) const;

        void setFixedFontFamily(const AtomicString&, UScriptCode = USCRIPT_COMMON);
        const AtomicString& fixedFontFamily(UScriptCode = USCRIPT_COMMON) const;

        void setSerifFontFamily(const AtomicString&, UScriptCode = USCRIPT_COMMON);
        const AtomicString& serifFontFamily(UScriptCode = USCRIPT_COMMON) const;

        void setSansSerifFontFamily(const AtomicString&, UScriptCode = USCRIPT_COMMON);
        const AtomicString& sansSerifFontFamily(UScriptCode = USCRIPT_COMMON) const;

        void setCursiveFontFamily(const AtomicString&, UScriptCode = USCRIPT_COMMON);
        const AtomicString& cursiveFontFamily(UScriptCode = USCRIPT_COMMON) const;

        void setFantasyFontFamily(const AtomicString&, UScriptCode = USCRIPT_COMMON);
        const AtomicString& fantasyFontFamily(UScriptCode = USCRIPT_COMMON) const;

        void setPictographFontFamily(const AtomicString&, UScriptCode = USCRIPT_COMMON);
        const AtomicString& pictographFontFamily(UScriptCode = USCRIPT_COMMON) const;

        void setMinimumFontSize(int);
        int minimumFontSize() const { return m_minimumFontSize; }

        void setMinimumLogicalFontSize(int);
        int minimumLogicalFontSize() const { return m_minimumLogicalFontSize; }

        void setDefaultFontSize(int);
        int defaultFontSize() const { return m_defaultFontSize; }

        void setDefaultFixedFontSize(int);
        int defaultFixedFontSize() const { return m_defaultFixedFontSize; }

        // Unlike areImagesEnabled, this only suppresses the network load of
        // the image URL.  A cached image will still be rendered if requested.
        void setLoadsImagesAutomatically(bool);
        bool loadsImagesAutomatically() const { return m_loadsImagesAutomatically; }

        // This setting only affects site icon image loading if loadsImagesAutomatically setting is false and this setting is true.
        // All other permutations still heed loadsImagesAutomatically setting.
        void setLoadsSiteIconsIgnoringImageLoadingSetting(bool);
        bool loadsSiteIconsIgnoringImageLoadingSetting() const { return m_loadsSiteIconsIgnoringImageLoadingSetting; }

        void setScriptEnabled(bool);
        // Instead of calling isScriptEnabled directly, please consider calling
        // ScriptController::canExecuteScripts, which takes things like the
        // HTML sandbox attribute into account.
        bool isScriptEnabled() const { return m_isScriptEnabled; }

        void setWebSecurityEnabled(bool);
        bool isWebSecurityEnabled() const { return m_isWebSecurityEnabled; }

        void setAllowUniversalAccessFromFileURLs(bool);
        bool allowUniversalAccessFromFileURLs() const { return m_allowUniversalAccessFromFileURLs; }

        void setAllowFileAccessFromFileURLs(bool);
        bool allowFileAccessFromFileURLs() const { return m_allowFileAccessFromFileURLs; }

        void setJavaScriptCanOpenWindowsAutomatically(bool);
        bool javaScriptCanOpenWindowsAutomatically() const { return m_javaScriptCanOpenWindowsAutomatically; }

        void setJavaScriptCanAccessClipboard(bool);
        bool javaScriptCanAccessClipboard() const { return m_javaScriptCanAccessClipboard; }

        void setSpatialNavigationEnabled(bool);
        bool isSpatialNavigationEnabled() const { return m_isSpatialNavigationEnabled; }

        void setJavaEnabled(bool);
        bool isJavaEnabled() const { return m_isJavaEnabled; }

        void setImagesEnabled(bool);
        bool areImagesEnabled() const { return m_areImagesEnabled; }

        void setMediaEnabled(bool);
        bool isMediaEnabled() const { return m_isMediaEnabled; }

        void setPluginsEnabled(bool);
        bool arePluginsEnabled() const { return m_arePluginsEnabled; }

        void setLocalStorageEnabled(bool);
        bool localStorageEnabled() const { return m_localStorageEnabled; }

        // Allow clients concerned with memory consumption to set a quota on session storage
        // since the memory used won't be released until the Page is destroyed.
        // Default is noQuota.
        void setSessionStorageQuota(unsigned);
        unsigned sessionStorageQuota() const { return m_sessionStorageQuota; }

        // When this option is set, WebCore will avoid storing any record of browsing activity
        // that may persist on disk or remain displayed when the option is reset.
        // This option does not affect the storage of such information in RAM.
        // The following functions respect this setting:
        //  - HTML5/DOM Storage
        //  - Icon Database
        //  - Console Messages
        //  - MemoryCache
        //  - Application Cache
        //  - Back/Forward Page History
        //  - Page Search Results
        //  - HTTP Cookies
        //  - Plug-ins (that support NPNVprivateModeBool)
        void setPrivateBrowsingEnabled(bool);
        bool privateBrowsingEnabled() const { return m_privateBrowsingEnabled; }

        void setCaretBrowsingEnabled(bool);
        bool caretBrowsingEnabled() const { return m_caretBrowsingEnabled; }

        void setDefaultTextEncodingName(const String&);
        const String& defaultTextEncodingName() const { return m_defaultTextEncodingName; }
        
        void setUsesEncodingDetector(bool);
        bool usesEncodingDetector() const { return m_usesEncodingDetector; }

        void setDNSPrefetchingEnabled(bool);
        bool dnsPrefetchingEnabled() const { return m_dnsPrefetchingEnabled; }

        void setUserStyleSheetLocation(const KURL&);
        const KURL& userStyleSheetLocation() const { return m_userStyleSheetLocation; }

        void setShouldPrintBackgrounds(bool);
        bool shouldPrintBackgrounds() const { return m_shouldPrintBackgrounds; }

        void setTextAreasAreResizable(bool);
        bool textAreasAreResizable() const { return m_textAreasAreResizable; }

        void setEditableLinkBehavior(EditableLinkBehavior);
        EditableLinkBehavior editableLinkBehavior() const { return m_editableLinkBehavior; }

        void setTextDirectionSubmenuInclusionBehavior(TextDirectionSubmenuInclusionBehavior);
        TextDirectionSubmenuInclusionBehavior textDirectionSubmenuInclusionBehavior() const { return m_textDirectionSubmenuInclusionBehavior; }

#if ENABLE(DASHBOARD_SUPPORT)
        void setUsesDashboardBackwardCompatibilityMode(bool);
        bool usesDashboardBackwardCompatibilityMode() const { return m_usesDashboardBackwardCompatibilityMode; }
#endif
        
        void setNeedsAdobeFrameReloadingQuirk(bool);
        bool needsAcrobatFrameReloadingQuirk() const { return m_needsAdobeFrameReloadingQuirk; }

        void setNeedsKeyboardEventDisambiguationQuirks(bool);
        bool needsKeyboardEventDisambiguationQuirks() const { return m_needsKeyboardEventDisambiguationQuirks; }

        void setTreatsAnyTextCSSLinkAsStylesheet(bool);
        bool treatsAnyTextCSSLinkAsStylesheet() const { return m_treatsAnyTextCSSLinkAsStylesheet; }

        void setNeedsLeopardMailQuirks(bool);
        bool needsLeopardMailQuirks() const { return m_needsLeopardMailQuirks; }

        void setDOMPasteAllowed(bool);
        bool isDOMPasteAllowed() const { return m_isDOMPasteAllowed; }
        
        static void setDefaultMinDOMTimerInterval(double); // Interval specified in seconds.
        static double defaultMinDOMTimerInterval();
        
        void setMinDOMTimerInterval(double); // Per-page; initialized to default value.
        double minDOMTimerInterval();

        void setUsesPageCache(bool);
        bool usesPageCache() const { return m_usesPageCache; }
        
        void setPageCacheSupportsPlugins(bool pageCacheSupportsPlugins) { m_pageCacheSupportsPlugins = pageCacheSupportsPlugins; }
        bool pageCacheSupportsPlugins() const { return m_pageCacheSupportsPlugins; }

        void setShrinksStandaloneImagesToFit(bool);
        bool shrinksStandaloneImagesToFit() const { return m_shrinksStandaloneImagesToFit; }

        void setShowsURLsInToolTips(bool);
        bool showsURLsInToolTips() const { return m_showsURLsInToolTips; }

        void setShowsToolTipOverTruncatedText(bool);
        bool showsToolTipOverTruncatedText() const { return m_showsToolTipOverTruncatedText; }

        void setFTPDirectoryTemplatePath(const String&);
        const String& ftpDirectoryTemplatePath() const { return m_ftpDirectoryTemplatePath; }
        
        void setForceFTPDirectoryListings(bool);
        bool forceFTPDirectoryListings() const { return m_forceFTPDirectoryListings; }
        
        void setDeveloperExtrasEnabled(bool);
        bool developerExtrasEnabled() const { return m_developerExtrasEnabled; }

        void setFrameFlatteningEnabled(bool);
        bool frameFlatteningEnabled() const { return m_frameFlatteningEnabled; }

        void setAuthorAndUserStylesEnabled(bool);
        bool authorAndUserStylesEnabled() const { return m_authorAndUserStylesEnabled; }
        
        void setFontRenderingMode(FontRenderingMode mode);
        FontRenderingMode fontRenderingMode() const;

        void setNeedsSiteSpecificQuirks(bool);
        bool needsSiteSpecificQuirks() const { return m_needsSiteSpecificQuirks; }

#if ENABLE(WEB_ARCHIVE)
        void setWebArchiveDebugModeEnabled(bool);
        bool webArchiveDebugModeEnabled() const { return m_webArchiveDebugModeEnabled; }
#endif

        void setLocalFileContentSniffingEnabled(bool);
        bool localFileContentSniffingEnabled() const { return m_localFileContentSniffingEnabled; }

        void setLocalStorageDatabasePath(const String&);
        const String& localStorageDatabasePath() const { return m_localStorageDatabasePath; }

        void setApplicationChromeMode(bool);
        bool inApplicationChromeMode() const { return m_inApplicationChromeMode; }

        void setOfflineWebApplicationCacheEnabled(bool);
        bool offlineWebApplicationCacheEnabled() const { return m_offlineWebApplicationCacheEnabled; }
        
        void setEnforceCSSMIMETypeInNoQuirksMode(bool);
        bool enforceCSSMIMETypeInNoQuirksMode() { return m_enforceCSSMIMETypeInNoQuirksMode; }

        void setMaximumDecodedImageSize(size_t size) { m_maximumDecodedImageSize = size; }
        size_t maximumDecodedImageSize() const { return m_maximumDecodedImageSize; }

        void setAllowScriptsToCloseWindows(bool);
        bool allowScriptsToCloseWindows() const { return m_allowScriptsToCloseWindows; }

        void setEditingBehaviorType(EditingBehaviorType behavior) { m_editingBehaviorType = behavior; }
        EditingBehaviorType editingBehaviorType() const { return static_cast<EditingBehaviorType>(m_editingBehaviorType); }

        void setDownloadableBinaryFontsEnabled(bool);
        bool downloadableBinaryFontsEnabled() const { return m_downloadableBinaryFontsEnabled; }

        void setXSSAuditorEnabled(bool);
        bool xssAuditorEnabled() const { return m_xssAuditorEnabled; }

        void setCanvasUsesAcceleratedDrawing(bool);
        bool canvasUsesAcceleratedDrawing() const { return m_canvasUsesAcceleratedDrawing; }

        void setAcceleratedDrawingEnabled(bool enabled) { m_acceleratedDrawingEnabled = enabled; }
        bool acceleratedDrawingEnabled() const { return m_acceleratedDrawingEnabled; }

        void setAcceleratedFiltersEnabled(bool enabled) { m_acceleratedFiltersEnabled = enabled; }
        bool acceleratedFiltersEnabled() const { return m_acceleratedFiltersEnabled; }

        void setCSSCustomFilterEnabled(bool enabled) { m_isCSSCustomFilterEnabled = enabled; }
        bool isCSSCustomFilterEnabled() const { return m_isCSSCustomFilterEnabled; }

        void setAcceleratedCompositingEnabled(bool);
        bool acceleratedCompositingEnabled() const { return m_acceleratedCompositingEnabled; }

        void setAcceleratedCompositingFor3DTransformsEnabled(bool);
        bool acceleratedCompositingFor3DTransformsEnabled() const { return m_acceleratedCompositingFor3DTransformsEnabled; }

        void setAcceleratedCompositingForVideoEnabled(bool);
        bool acceleratedCompositingForVideoEnabled() const { return m_acceleratedCompositingForVideoEnabled; }

        void setAcceleratedCompositingForPluginsEnabled(bool);
        bool acceleratedCompositingForPluginsEnabled() const { return m_acceleratedCompositingForPluginsEnabled; }

        void setAcceleratedCompositingForCanvasEnabled(bool);
        bool acceleratedCompositingForCanvasEnabled() const { return m_acceleratedCompositingForCanvasEnabled; }

        void setAcceleratedCompositingForAnimationEnabled(bool);
        bool acceleratedCompositingForAnimationEnabled() const { return m_acceleratedCompositingForAnimationEnabled; }

        void setAcceleratedCompositingForFixedPositionEnabled(bool enabled) { m_acceleratedCompositingForFixedPositionEnabled = enabled; }
        bool acceleratedCompositingForFixedPositionEnabled() const { return m_acceleratedCompositingForFixedPositionEnabled; }

        void setAcceleratedCompositingForScrollableFramesEnabled(bool enabled) { m_acceleratedCompositingForScrollableFramesEnabled = enabled; }
        bool acceleratedCompositingForScrollableFramesEnabled() const { return m_acceleratedCompositingForScrollableFramesEnabled; }

        void setShowDebugBorders(bool);
        bool showDebugBorders() const { return m_showDebugBorders; }

        void setShowRepaintCounter(bool);
        bool showRepaintCounter() const { return m_showRepaintCounter; }

        void setExperimentalNotificationsEnabled(bool);
        bool experimentalNotificationsEnabled() const { return m_experimentalNotificationsEnabled; }

#if PLATFORM(WIN) || (OS(WINDOWS) && PLATFORM(WX))
        static void setShouldUseHighResolutionTimers(bool);
        static bool shouldUseHighResolutionTimers() { return gShouldUseHighResolutionTimers; }
#endif

        void setWebAudioEnabled(bool);
        bool webAudioEnabled() const { return m_webAudioEnabled; }

        void setWebGLEnabled(bool);
        bool webGLEnabled() const { return m_webGLEnabled; }

        void setOpenGLMultisamplingEnabled(bool);
        bool openGLMultisamplingEnabled() const { return m_openGLMultisamplingEnabled; }

        void setPrivilegedWebGLExtensionsEnabled(bool);
        bool privilegedWebGLExtensionsEnabled() const { return m_privilegedWebGLExtensionsEnabled; }

        void setAccelerated2dCanvasEnabled(bool);
        bool accelerated2dCanvasEnabled() const { return m_acceleratedCanvas2dEnabled; }

        // Number of pixels below which 2D canvas is rendered in software
        // even if hardware acceleration is enabled.
        // Hardware acceleration is useful for large canvases where it can avoid the
        // pixel bandwidth between the CPU and GPU. But GPU acceleration comes at
        // a price - extra back-buffer and texture copy. Small canvases are also
        // widely used for stylized fonts. Anti-aliasing text in hardware at that
        // scale is generally slower. So below a certain size it is better to
        // draw canvas in software.
        void setMinimumAccelerated2dCanvasSize(int);
        int minimumAccelerated2dCanvasSize() const { return m_minimumAccelerated2dCanvasSize; }

        void setLoadDeferringEnabled(bool);
        bool loadDeferringEnabled() const { return m_loadDeferringEnabled; }
        
        void setTiledBackingStoreEnabled(bool);
        bool tiledBackingStoreEnabled() const { return m_tiledBackingStoreEnabled; }

        void setPaginateDuringLayoutEnabled(bool flag) { m_paginateDuringLayoutEnabled = flag; }
        bool paginateDuringLayoutEnabled() const { return m_paginateDuringLayoutEnabled; }

#if ENABLE(FULLSCREEN_API)
        void setFullScreenEnabled(bool flag) { m_fullScreenAPIEnabled = flag; }
        bool fullScreenEnabled() const  { return m_fullScreenAPIEnabled; }
#endif

#if USE(AVFOUNDATION)
        static void setAVFoundationEnabled(bool flag) { gAVFoundationEnabled = flag; }
        static bool isAVFoundationEnabled() { return gAVFoundationEnabled; }
#endif

        void setAsynchronousSpellCheckingEnabled(bool flag) { m_asynchronousSpellCheckingEnabled = flag; }
        bool asynchronousSpellCheckingEnabled() const  { return m_asynchronousSpellCheckingEnabled; }

        void setUnifiedTextCheckerEnabled(bool flag) { m_unifiedTextCheckerEnabled = flag; }
        bool unifiedTextCheckerEnabled() const { return m_unifiedTextCheckerEnabled; }

        void setMemoryInfoEnabled(bool flag) { m_memoryInfoEnabled = flag; }
        bool memoryInfoEnabled() const { return m_memoryInfoEnabled; }

        // This setting will be removed when an HTML5 compatibility issue is
        // resolved and WebKit implementation of interactive validation is
        // completed. See http://webkit.org/b/40520, http://webkit.org/b/40747,
        // and http://webkit.org/b/40908
        void setInteractiveFormValidationEnabled(bool flag) { m_interactiveFormValidation = flag; }
        bool interactiveFormValidationEnabled() const { return m_interactiveFormValidation; }

        // Sets the maginication value for validation message timer.
        // If the maginication value is N, a validation message disappears
        // automatically after <message length> * N / 1000 seconds. If N is
        // equal to or less than 0, a validation message doesn't disappears
        // automaticaly. The default value is 50.
        void setValidationMessageTimerMagnification(int newValue) { m_validationMessageTimerMagnification = newValue; }
        int validationMessageTimerMaginification() const { return m_validationMessageTimerMagnification; }
        
        void setUsePreHTML5ParserQuirks(bool flag) { m_usePreHTML5ParserQuirks = flag; }
        bool usePreHTML5ParserQuirks() const { return m_usePreHTML5ParserQuirks; }

        static const unsigned defaultMaximumHTMLParserDOMTreeDepth = 512;
        void setMaximumHTMLParserDOMTreeDepth(unsigned maximumHTMLParserDOMTreeDepth) { m_maximumHTMLParserDOMTreeDepth = maximumHTMLParserDOMTreeDepth; }
        unsigned maximumHTMLParserDOMTreeDepth() const { return m_maximumHTMLParserDOMTreeDepth; }

        void setHyperlinkAuditingEnabled(bool flag) { m_hyperlinkAuditingEnabled = flag; }
        bool hyperlinkAuditingEnabled() const { return m_hyperlinkAuditingEnabled; }

        void setCrossOriginCheckInGetMatchedCSSRulesDisabled(bool flag) { m_crossOriginCheckInGetMatchedCSSRulesDisabled = flag; }
        bool crossOriginCheckInGetMatchedCSSRulesDisabled() const { return m_crossOriginCheckInGetMatchedCSSRulesDisabled; }
        
        void setLayoutFallbackWidth(int width) { m_layoutFallbackWidth = width; }
        int layoutFallbackWidth() const { return m_layoutFallbackWidth; }

        void setDeviceWidth(int width) { m_deviceWidth = width; }
        int deviceWidth() const { return m_deviceWidth; }

        void setDeviceHeight(int height) { m_deviceHeight = height; }
        int deviceHeight() const { return m_deviceHeight; }

        void setDeviceDPI(int deviceDPI) { m_deviceDPI = deviceDPI; }
        int deviceDPI() const { return m_deviceDPI; }

        void setForceCompositingMode(bool flag) { m_forceCompositingMode = flag; }
        bool forceCompositingMode() { return m_forceCompositingMode; }

        void setShouldInjectUserScriptsInInitialEmptyDocument(bool flag) { m_shouldInjectUserScriptsInInitialEmptyDocument = flag; }
        bool shouldInjectUserScriptsInInitialEmptyDocument() { return m_shouldInjectUserScriptsInInitialEmptyDocument; }

        void setAllowDisplayOfInsecureContent(bool flag) { m_allowDisplayOfInsecureContent = flag; }
        bool allowDisplayOfInsecureContent() const { return m_allowDisplayOfInsecureContent; }
        void setAllowRunningOfInsecureContent(bool flag) { m_allowRunningOfInsecureContent = flag; }
        bool allowRunningOfInsecureContent() const { return m_allowRunningOfInsecureContent; }

#if ENABLE(SMOOTH_SCROLLING)
        void setEnableScrollAnimator(bool flag) { m_scrollAnimatorEnabled = flag; }
        bool scrollAnimatorEnabled() const { return m_scrollAnimatorEnabled; }
#endif
#if ENABLE(WEB_SOCKETS)
        void setUseHixie76WebSocketProtocol(bool flag) { m_useHixie76WebSocketProtocol = flag; }
        bool useHixie76WebSocketProtocol() { return m_useHixie76WebSocketProtocol; }
#endif

        void setMediaPlaybackRequiresUserGesture(bool flag) { m_mediaPlaybackRequiresUserGesture = flag; };
        bool mediaPlaybackRequiresUserGesture() const { return m_mediaPlaybackRequiresUserGesture; }

        void setMediaPlaybackAllowsInline(bool flag) { m_mediaPlaybackAllowsInline = flag; };
        bool mediaPlaybackAllowsInline() const { return m_mediaPlaybackAllowsInline; }

        void setPasswordEchoEnabled(bool flag) { m_passwordEchoEnabled = flag; }
        bool passwordEchoEnabled() const { return m_passwordEchoEnabled; }

        void setSuppressIncrementalRendering(bool flag) { m_suppressIncrementalRendering = flag; }
        bool suppressIncrementalRendering() const { return m_suppressIncrementalRendering; }
        
        void setBackspaceKeyNavigationEnabled(bool flag) { m_backspaceKeyNavigationEnabled = flag; }
        bool backspaceKeyNavigationEnabled() const { return m_backspaceKeyNavigationEnabled; }
        
        void setPasswordEchoDurationInSeconds(double durationInSeconds) { m_passwordEchoDurationInSeconds = durationInSeconds; }
        double passwordEchoDurationInSeconds() const { return m_passwordEchoDurationInSeconds; }

#if USE(SAFARI_THEME)
        // Windows debugging pref (global) for switching between the Aqua look and a native windows look.
        static void setShouldPaintNativeControls(bool);
        static bool shouldPaintNativeControls() { return gShouldPaintNativeControls; }
#endif

        static void setMockScrollbarsEnabled(bool flag);
        static bool mockScrollbarsEnabled();

        void setVisualWordMovementEnabled(bool enabled) { m_visualWordMovementEnabled = enabled; }
        bool visualWordMovementEnabled() const { return m_visualWordMovementEnabled; }

#if ENABLE(VIDEO_TRACK)
        void setShouldDisplaySubtitles(bool flag) { m_shouldDisplaySubtitles = flag; }
        bool shouldDisplaySubtitles() const { return m_shouldDisplaySubtitles; }

        void setShouldDisplayCaptions(bool flag) { m_shouldDisplayCaptions = flag; }
        bool shouldDisplayCaptions() const { return m_shouldDisplayCaptions; }

        void setShouldDisplayTextDescriptions(bool flag) { m_shouldDisplayTextDescriptions = flag; }
        bool shouldDisplayTextDescriptions() const { return m_shouldDisplayTextDescriptions; }
#endif

        void setPerTileDrawingEnabled(bool enabled) { m_perTileDrawingEnabled = enabled; }
        bool perTileDrawingEnabled() const { return m_perTileDrawingEnabled; }

        void setPartialSwapEnabled(bool enabled) { m_partialSwapEnabled = enabled; }
        bool partialSwapEnabled() const { return m_partialSwapEnabled; }

#if ENABLE(THREADED_SCROLLING)
        void setScrollingCoordinatorEnabled(bool enabled) { m_scrollingCoordinatorEnabled = enabled; }
        bool scrollingCoordinatorEnabled() const { return m_scrollingCoordinatorEnabled; }
#endif

        void setNotificationsEnabled(bool enabled) { m_notificationsEnabled = enabled; }
        bool notificationsEnabled() const { return m_notificationsEnabled; }

    private:
        Settings(Page*);

        Page* m_page;

        String m_defaultTextEncodingName;
        String m_ftpDirectoryTemplatePath;
        String m_localStorageDatabasePath;
        KURL m_userStyleSheetLocation;
        ScriptFontFamilyMap m_standardFontFamilyMap;
        ScriptFontFamilyMap m_serifFontFamilyMap;
        ScriptFontFamilyMap m_fixedFontFamilyMap;
        ScriptFontFamilyMap m_sansSerifFontFamilyMap;
        ScriptFontFamilyMap m_cursiveFontFamilyMap;
        ScriptFontFamilyMap m_fantasyFontFamilyMap;
        ScriptFontFamilyMap m_pictographFontFamilyMap;
        EditableLinkBehavior m_editableLinkBehavior;
        TextDirectionSubmenuInclusionBehavior m_textDirectionSubmenuInclusionBehavior;
        double m_passwordEchoDurationInSeconds;
        int m_minimumFontSize;
        int m_minimumLogicalFontSize;
        int m_defaultFontSize;
        int m_defaultFixedFontSize;
        int m_validationMessageTimerMagnification;
        int m_minimumAccelerated2dCanvasSize;
        int m_layoutFallbackWidth;
        int m_deviceDPI;
        size_t m_maximumDecodedImageSize;
        int m_deviceWidth;
        int m_deviceHeight;
        unsigned m_sessionStorageQuota;
        unsigned m_editingBehaviorType;
        unsigned m_maximumHTMLParserDOMTreeDepth;
        bool m_isSpatialNavigationEnabled : 1;
        bool m_isJavaEnabled : 1;
        bool m_loadsImagesAutomatically : 1;
        bool m_loadsSiteIconsIgnoringImageLoadingSetting : 1;
        bool m_privateBrowsingEnabled : 1;
        bool m_caretBrowsingEnabled : 1;
        bool m_areImagesEnabled : 1;
        bool m_isMediaEnabled : 1;
        bool m_arePluginsEnabled : 1;
        bool m_localStorageEnabled : 1;
        bool m_isScriptEnabled : 1;
        bool m_isWebSecurityEnabled : 1;
        bool m_allowUniversalAccessFromFileURLs: 1;
        bool m_allowFileAccessFromFileURLs: 1;
        bool m_javaScriptCanOpenWindowsAutomatically : 1;
        bool m_javaScriptCanAccessClipboard : 1;
        bool m_shouldPrintBackgrounds : 1;
        bool m_textAreasAreResizable : 1;
#if ENABLE(DASHBOARD_SUPPORT)
        bool m_usesDashboardBackwardCompatibilityMode : 1;
#endif
        bool m_needsAdobeFrameReloadingQuirk : 1;
        bool m_needsKeyboardEventDisambiguationQuirks : 1;
        bool m_treatsAnyTextCSSLinkAsStylesheet : 1;
        bool m_needsLeopardMailQuirks : 1;
        bool m_isDOMPasteAllowed : 1;
        bool m_shrinksStandaloneImagesToFit : 1;
        bool m_usesPageCache : 1;
        bool m_pageCacheSupportsPlugins : 1;
        bool m_showsURLsInToolTips : 1;
        bool m_showsToolTipOverTruncatedText : 1;
        bool m_forceFTPDirectoryListings : 1;
        bool m_developerExtrasEnabled : 1;
        bool m_authorAndUserStylesEnabled : 1;
        bool m_needsSiteSpecificQuirks : 1;
        unsigned m_fontRenderingMode : 1;
        bool m_frameFlatteningEnabled : 1;
        bool m_webArchiveDebugModeEnabled : 1;
        bool m_localFileContentSniffingEnabled : 1;
        bool m_inApplicationChromeMode : 1;
        bool m_offlineWebApplicationCacheEnabled : 1;
        bool m_enforceCSSMIMETypeInNoQuirksMode : 1;
        bool m_usesEncodingDetector : 1;
        bool m_allowScriptsToCloseWindows : 1;
        bool m_canvasUsesAcceleratedDrawing : 1;
        bool m_acceleratedDrawingEnabled : 1;
        bool m_acceleratedFiltersEnabled : 1;
        bool m_isCSSCustomFilterEnabled : 1;
        bool m_downloadableBinaryFontsEnabled : 1;
        bool m_xssAuditorEnabled : 1;
        bool m_acceleratedCompositingEnabled : 1;
        bool m_acceleratedCompositingFor3DTransformsEnabled : 1;
        bool m_acceleratedCompositingForVideoEnabled : 1;
        bool m_acceleratedCompositingForPluginsEnabled : 1;
        bool m_acceleratedCompositingForCanvasEnabled : 1;
        bool m_acceleratedCompositingForAnimationEnabled : 1;
        bool m_acceleratedCompositingForFixedPositionEnabled : 1;
        bool m_acceleratedCompositingForScrollableFramesEnabled : 1; // Works only in conjunction with forceCompositingMode
        bool m_showDebugBorders : 1;
        bool m_showRepaintCounter : 1;
        bool m_experimentalNotificationsEnabled : 1;
        bool m_webGLEnabled : 1;
        bool m_openGLMultisamplingEnabled : 1;
        bool m_privilegedWebGLExtensionsEnabled : 1;
        bool m_webAudioEnabled : 1;
        bool m_acceleratedCanvas2dEnabled : 1;
        bool m_loadDeferringEnabled : 1;
        bool m_tiledBackingStoreEnabled : 1;
        bool m_paginateDuringLayoutEnabled : 1;
        bool m_dnsPrefetchingEnabled : 1;
#if ENABLE(FULLSCREEN_API)
        bool m_fullScreenAPIEnabled : 1;
#endif
        bool m_asynchronousSpellCheckingEnabled: 1;
        bool m_unifiedTextCheckerEnabled: 1;
        bool m_memoryInfoEnabled: 1;
        bool m_interactiveFormValidation: 1;
        bool m_usePreHTML5ParserQuirks: 1;
        bool m_hyperlinkAuditingEnabled : 1;
        bool m_crossOriginCheckInGetMatchedCSSRulesDisabled : 1;
        bool m_forceCompositingMode : 1;
        bool m_shouldInjectUserScriptsInInitialEmptyDocument : 1;
        bool m_allowDisplayOfInsecureContent : 1;
        bool m_allowRunningOfInsecureContent : 1;
#if ENABLE(SMOOTH_SCROLLING)
        bool m_scrollAnimatorEnabled : 1;
#endif
#if ENABLE(WEB_SOCKETS)
        bool m_useHixie76WebSocketProtocol : 1;
#endif
        bool m_mediaPlaybackRequiresUserGesture : 1;
        bool m_mediaPlaybackAllowsInline : 1;
        bool m_passwordEchoEnabled : 1;
        bool m_suppressIncrementalRendering : 1;
        bool m_backspaceKeyNavigationEnabled : 1;
        bool m_visualWordMovementEnabled : 1;

#if ENABLE(VIDEO_TRACK)
        bool m_shouldDisplaySubtitles : 1;
        bool m_shouldDisplayCaptions : 1;
        bool m_shouldDisplayTextDescriptions : 1;
#endif
        bool m_perTileDrawingEnabled : 1;
        bool m_partialSwapEnabled : 1;

#if ENABLE(THREADED_SCROLLING)
        bool m_scrollingCoordinatorEnabled : 1;
#endif

        bool m_notificationsEnabled : 1;

        Timer<Settings> m_loadsImagesAutomaticallyTimer;
        void loadsImagesAutomaticallyTimerFired(Timer<Settings>*);

#if USE(AVFOUNDATION)
        static bool gAVFoundationEnabled;
#endif
        static bool gMockScrollbarsEnabled;

#if USE(SAFARI_THEME)
        static bool gShouldPaintNativeControls;
#endif
#if PLATFORM(WIN) || (OS(WINDOWS) && PLATFORM(WX))
        static bool gShouldUseHighResolutionTimers;
#endif
    };

} // namespace WebCore

#endif // Settings_h
