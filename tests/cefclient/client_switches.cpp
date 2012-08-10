// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

// This file is shared by cefclient and cef_unittests so don't include using
// a qualified path.
#include "client_switches.h"  // NOLINT(build/include)

namespace cefclient {

const char kUrl[] = "url";
const char kExternalDevTools[] = "external-devtools";

// CefSettings attributes.
const char kMultiThreadedMessageLoop[] = "multi-threaded-message-loop";
const char kCachePath[] = "cache-path";

// CefBrowserSettings attributes.
const char kRemoteFontsDisabled[] = "remote-fonts-disabled";
const char kDefaultEncoding[] = "default-encoding";
const char kEncodingDetectorEnabled[] = "encoding-detector-enabled";
const char kJavascriptDisabled[] = "javascript-disabled";
const char kJavascriptOpenWindowsDisallowed[] =
    "javascript-open-windows-disallowed";
const char kJavascriptCloseWindowsDisallowed[] =
    "javascript-close-windows-disallowed";
const char kJavascriptAccessClipboardDisallowed[] =
    "javascript-access-clipboard-disallowed";
const char kDomPasteDisabled[] = "dom-paste-disabled";
const char kCaretBrowsingDisabled[] = "caret-browsing-enabled";
const char kJavaDisabled[] = "java-disabled";
const char kPluginsDisabled[] = "plugins-disabled";
const char kUniversalAccessFromFileUrlsAllowed[] =
    "universal-access-from-file-urls-allowed";
const char kFileAccessFromFileUrlsAllowed[] =
    "file-access-from-file-urls-allowed";
const char kWebSecurityDisabled[] = "web-security-disabled";
const char kXssAuditorEnabled[] = "xss-auditor-enabled";
const char kImageLoadingDisabled[] = "image-load-disabled";
const char kShrinkStandaloneImagesToFit[] = "shrink-standalone-images-to-fit";
const char kSiteSpecificQuirksDisabled[] = "site-specific-quirks-disabled";
const char kTextAreaResizeDisabled[] = "text-area-resize-disabled";
const char kPageCacheDisabled[] = "page-cache-disabled";
const char kTabToLinksDisabled[] = "tab-to-links-disabled";
const char kHyperlinkAuditingDisabled[] = "hyperlink-auditing-disabled";
const char kUserStyleSheetEnabled[] = "user-style-sheet-enabled";
const char kUserStyleSheetLocation[] = "user-style-sheet-location";
const char kAuthorAndUserStylesDisabled[] = "author-and-user-styles-disabled";
const char kLocalStorageDisabled[] = "local-storage-disabled";
const char kDatabasesDisabled[] = "databases-disabled";
const char kApplicationCacheDisabled[] = "application-cache-disabled";
const char kWebglDisabled[] = "webgl-disabled";
const char kAcceleratedCompositingDisabled[] =
    "accelerated-compositing-disabled";
const char kAcceleratedLayersDisabled[] = "accelerated-layers-disabled";
const char kAcceleratedVideoDisabled[] = "accelerated-video-disabled";
const char kAcceledated2dCanvasDisabled[] = "accelerated-2d-canvas-disabled";
const char kAcceleratedPaintingEnabled[] = "accelerated-painting-enabled";
const char kAcceleratedFiltersEnabled[] = "accelerated-filters-enabled";
const char kAcceleratedPluginsDisabled[] = "accelerated-plugins-disabled";
const char kDeveloperToolsDisabled[] = "developer-tools-disabled";
const char kFullscreenEnabled[] = "fullscreen-enabled";

// Other attributes.
const char kProxyType[] = "proxy-type";
const char kProxyType_Direct[] = "direct";
const char kProxyType_Named[] = "named";
const char kProxyType_Pac[] = "pac";
const char kProxyConfig[] = "proxy-config";

}  // namespace cefclient
