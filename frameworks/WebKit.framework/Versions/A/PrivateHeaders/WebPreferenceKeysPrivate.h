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

// These are private because callers should be using the cover methods. They are in
// a Private (as opposed to Internal) header file because Safari uses some of them
// for managed preferences.
#define WebKitLogLevelPreferenceKey @"WebKitLogLevel"
#define WebKitStandardFontPreferenceKey @"WebKitStandardFont"
#define WebKitFixedFontPreferenceKey @"WebKitFixedFont"
#define WebKitSerifFontPreferenceKey @"WebKitSerifFont"
#define WebKitSansSerifFontPreferenceKey @"WebKitSansSerifFont"
#define WebKitCursiveFontPreferenceKey @"WebKitCursiveFont"
#define WebKitFantasyFontPreferenceKey @"WebKitFantasyFont"
#define WebKitPictographFontPreferenceKey @"WebKitPictographFont"
#define WebKitMinimumFontSizePreferenceKey @"WebKitMinimumFontSize"
#define WebKitMinimumLogicalFontSizePreferenceKey @"WebKitMinimumLogicalFontSize"
#define WebKitDefaultFontSizePreferenceKey @"WebKitDefaultFontSize"
#define WebKitDefaultFixedFontSizePreferenceKey @"WebKitDefaultFixedFontSize"
#define WebKitDefaultTextEncodingNamePreferenceKey @"WebKitDefaultTextEncodingName"
#define WebKitUsesEncodingDetectorPreferenceKey @"WebKitUsesEncodingDetector"
#define WebKitUserStyleSheetEnabledPreferenceKey @"WebKitUserStyleSheetEnabledPreferenceKey"
#define WebKitUserStyleSheetLocationPreferenceKey @"WebKitUserStyleSheetLocationPreferenceKey"
#define WebKitShouldPrintBackgroundsPreferenceKey @"WebKitShouldPrintBackgroundsPreferenceKey"
#define WebKitTextAreasAreResizablePreferenceKey @"WebKitTextAreasAreResizable"
#define WebKitShrinksStandaloneImagesToFitPreferenceKey @"WebKitShrinksStandaloneImagesToFit"
#define WebKitJavaEnabledPreferenceKey @"WebKitJavaEnabled"
#define WebKitJavaScriptEnabledPreferenceKey @"WebKitJavaScriptEnabled"
#define WebKitWebSecurityEnabledPreferenceKey @"WebKitWebSecurityEnabled"
#define WebKitAllowUniversalAccessFromFileURLsPreferenceKey @"WebKitAllowUniversalAccessFromFileURLs"
#define WebKitAllowFileAccessFromFileURLsPreferenceKey @"WebKitAllowFileAccessFromFileURLs"
#define WebKitJavaScriptCanOpenWindowsAutomaticallyPreferenceKey @"WebKitJavaScriptCanOpenWindowsAutomatically"
#define WebKitPluginsEnabledPreferenceKey @"WebKitPluginsEnabled"
#define WebKitDatabasesEnabledPreferenceKey @"WebKitDatabasesEnabledPreferenceKey"
#define WebKitLocalStorageEnabledPreferenceKey @"WebKitLocalStorageEnabledPreferenceKey"
#define WebKitExperimentalNotificationsEnabledPreferenceKey @"WebKitExperimentalNotificationsEnabledPreferenceKey"
#define WebKitAllowAnimatedImagesPreferenceKey @"WebKitAllowAnimatedImagesPreferenceKey"
#define WebKitAllowAnimatedImageLoopingPreferenceKey @"WebKitAllowAnimatedImageLoopingPreferenceKey"
#define WebKitDisplayImagesKey @"WebKitDisplayImagesKey"
#define WebKitLoadSiteIconsKey @"WebKitLoadSiteIconsKey"
#define WebKitBackForwardCacheExpirationIntervalKey @"WebKitBackForwardCacheExpirationIntervalKey"
#define WebKitTabToLinksPreferenceKey @"WebKitTabToLinksPreferenceKey"
#define WebKitPrivateBrowsingEnabledPreferenceKey @"WebKitPrivateBrowsingEnabled"
#define WebSmartInsertDeleteEnabled @"WebSmartInsertDeleteEnabled"
#define WebContinuousSpellCheckingEnabled @"WebContinuousSpellCheckingEnabled"
#define WebGrammarCheckingEnabled @"WebGrammarCheckingEnabled"
#define WebAutomaticQuoteSubstitutionEnabled @"WebAutomaticQuoteSubstitutionEnabled"
#define WebAutomaticLinkDetectionEnabled @"WebAutomaticLinkDetectionEnabled"
#define WebAutomaticDashSubstitutionEnabled @"WebAutomaticDashSubstitutionEnabled"
#define WebAutomaticTextReplacementEnabled @"WebAutomaticTextReplacementEnabled"
#define WebAutomaticSpellingCorrectionEnabled @"WebAutomaticSpellingCorrectionEnabled"
#define WebKitDOMPasteAllowedPreferenceKey @"WebKitDOMPasteAllowedPreferenceKey"
#define WebKitUsesPageCachePreferenceKey @"WebKitUsesPageCachePreferenceKey"
#define WebKitPageCacheSupportsPluginsPreferenceKey @"WebKitPageCacheSupportsPluginsPreferenceKey"
#define WebKitFTPDirectoryTemplatePath @"WebKitFTPDirectoryTemplatePath"
#define WebKitForceFTPDirectoryListings @"WebKitForceFTPDirectoryListings"
#define WebKitDeveloperExtrasEnabledPreferenceKey @"WebKitDeveloperExtrasEnabledPreferenceKey"
#define WebKitAuthorAndUserStylesEnabledPreferenceKey @"WebKitAuthorAndUserStylesEnabledPreferenceKey"
#define WebKitApplicationChromeModeEnabledPreferenceKey @"WebKitApplicationChromeModeEnabledPreferenceKey"
#define WebKitWebArchiveDebugModeEnabledPreferenceKey @"WebKitWebArchiveDebugModeEnabledPreferenceKey"
#define WebKitLocalFileContentSniffingEnabledPreferenceKey @"WebKitLocalFileContentSniffingEnabledPreferenceKey"
#define WebKitLocalStorageDatabasePathPreferenceKey @"WebKitLocalStorageDatabasePathPreferenceKey"
#define WebKitEnableFullDocumentTeardownPreferenceKey @"WebKitEnableFullDocumentTeardown"
#define WebKitOfflineWebApplicationCacheEnabledPreferenceKey @"WebKitOfflineWebApplicationCacheEnabled"
#define WebKitApplicationCacheTotalQuota @"WebKitApplicationCacheTotalQuota"
#define WebKitApplicationCacheDefaultOriginQuota @"WebKitApplicationCacheDefaultOriginQuota"
#define WebKitZoomsTextOnlyPreferenceKey @"WebKitZoomsTextOnly"
#define WebKitJavaScriptCanAccessClipboardPreferenceKey @"WebKitJavaScriptCanAccessClipboard"
#define WebKitXSSAuditorEnabledPreferenceKey @"WebKitXSSAuditorEnabled"
#define WebKitAcceleratedDrawingEnabledPreferenceKey @"WebKitAcceleratedDrawingEnabled"
#define WebKitCanvasUsesAcceleratedDrawingPreferenceKey @"WebKitCanvasUsesAcceleratedDrawing"
#define WebKitAcceleratedCompositingEnabledPreferenceKey @"WebKitAcceleratedCompositingEnabled"
#define WebKitCSSCustomFilterEnabledPreferenceKey @"WebKitCSSCustomFilterEnabled"
#define WebKitShowDebugBordersPreferenceKey @"WebKitShowDebugBorders"
#define WebKitShowRepaintCounterPreferenceKey @"WebKitShowRepaintCounter"
#define WebKitWebAudioEnabledPreferenceKey @"WebKitWebAudioEnabled"
#define WebKitWebGLEnabledPreferenceKey @"WebKitWebGLEnabled"
#define WebKitAccelerated2dCanvasEnabledPreferenceKey @"WebKitAccelerated2dCanvasEnabled"
#define WebKitFrameFlatteningEnabledPreferenceKey @"WebKitFrameFlatteningEnabled"
#define WebKitSpatialNavigationEnabledPreferenceKey @"WebKitSpatialNavigationEnabled"
#define WebKitPaginateDuringLayoutEnabledPreferenceKey @"WebKitPaginateDuringLayoutEnabled"
#define WebKitDNSPrefetchingEnabledPreferenceKey @"WebKitDNSPrefetchingEnabled"
#define WebKitFullScreenEnabledPreferenceKey @"WebKitFullScreenEnabled"
#define WebKitAsynchronousSpellCheckingEnabledPreferenceKey @"WebKitAsynchronousSpellCheckingEnabled"
#define WebKitMemoryInfoEnabledPreferenceKey @"WebKitMemoryInfoEnabled"
#define WebKitHyperlinkAuditingEnabledPreferenceKey @"WebKitHyperlinkAuditingEnabled"
#define WebKitAVFoundationEnabledKey @"WebKitAVFoundationEnabled"
#define WebKitHixie76WebSocketProtocolEnabledKey @"WebKitHixie76WebSocketProtocolEnabled"
#define WebKitMediaPlaybackRequiresUserGesturePreferenceKey @"WebKitMediaPlaybackRequiresUserGesture"
#define WebKitMediaPlaybackAllowsInlinePreferenceKey @"WebKitMediaPlaybackAllowsInline"
#define WebKitMockScrollbarsEnabledPreferenceKey @"WebKitMockScrollbarsEnabled"
#define WebKitShouldDisplaySubtitlesPreferenceKey @"WebKitShouldDisplaySubtitles"
#define WebKitShouldDisplayCaptionsPreferenceKey @"WebKitShouldDisplayCaptions"
#define WebKitShouldDisplayTextDescriptionsPreferenceKey @"WebKitShouldDisplayTextDescriptions"

// These are private both because callers should be using the cover methods and because the
// cover methods themselves are private.
#define WebKitRespectStandardStyleKeyEquivalentsPreferenceKey @"WebKitRespectStandardStyleKeyEquivalents"
#define WebKitShowsURLsInToolTipsPreferenceKey @"WebKitShowsURLsInToolTips"
#define WebKitShowsToolTipOverTruncatedTextPreferenceKey @"WebKitShowsToolTipOverTruncatedText"
#define WebKitPDFDisplayModePreferenceKey @"WebKitPDFDisplayMode"
#define WebKitPDFScaleFactorPreferenceKey @"WebKitPDFScaleFactor"
#define WebKitUseSiteSpecificSpoofingPreferenceKey @"WebKitUseSiteSpecificSpoofing"
#define WebKitEditableLinkBehaviorPreferenceKey @"WebKitEditableLinkBehavior"
#define WebKitCacheModelPreferenceKey @"WebKitCacheModelPreferenceKey"
#define WebKitTextDirectionSubmenuInclusionBehaviorPreferenceKey @"WebKitTextDirectionSubmenuInclusionBehaviorPreferenceKey"
#define WebKitEditingBehaviorPreferenceKey @"WebKitEditingBehavior"
#define WebKitUsePreHTML5ParserQuirksKey @"WebKitUsePreHTML5ParserQuirks"
#define WebKitSuppressIncrementalRenderingKey @"WebKitSuppressIncrementalRendering"
#define WebKitBackspaceKeyNavigationEnabledKey @"WebKitBackspaceKeyNavigationEnabled"

// CoreGraphics deferred updates are disabled if WebKitEnableCoalescedUpdatesPreferenceKey is set
// to NO, or has no value.  For compatibility with Mac OS X 10.4.6, deferred updates are OFF by
// default.
#define WebKitEnableDeferredUpdatesPreferenceKey @"WebKitEnableDeferredUpdates"

// For debugging only. Don't use these.
#define WebKitPageCacheSizePreferenceKey @"WebKitPageCacheSizePreferenceKey"
#define WebKitObjectCacheSizePreferenceKey @"WebKitObjectCacheSizePreferenceKey"
#define WebKitDebugFullPageZoomPreferenceKey @"WebKitDebugFullPageZoomPreferenceKey"
