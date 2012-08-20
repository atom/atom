// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "cefclient/cefclient.h"
#include <stdio.h>
#include <cstdlib>
#include <sstream>
#include <string>
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/cef_frame.h"
#include "include/cef_runnable.h"
#include "include/cef_web_plugin.h"
#include "cefclient/client_handler.h"
#include "cefclient/util.h"

CefRefPtr<ClientHandler> g_handler;
CefRefPtr<CefCommandLine> g_command_line;

CefWindowHandle AppGetMainHwnd() {
  if (!g_handler.get())
    return NULL;
  return g_handler->GetMainHwnd();
}

void AppInitCommandLine(int argc, const char* const* argv) {
  g_command_line = CefCommandLine::CreateCommandLine();
#if defined(OS_WIN)
  g_command_line->InitFromString(::GetCommandLineW());
#else
  g_command_line->InitFromArgv(argc, argv);
#endif
}

// Returns the application command line object.
CefRefPtr<CefCommandLine> AppGetCommandLine() {
  return g_command_line;
}

// Returns the application settings based on command line arguments.
void AppGetSettings(CefSettings& settings, CefRefPtr<ClientApp> app) {
  ASSERT(app.get());
  ASSERT(g_command_line.get());
  if (!g_command_line.get())
    return;

  CefString str;

#if defined(OS_WIN)
  settings.multi_threaded_message_loop =
      g_command_line->HasSwitch("multi-threaded-message-loop");
#endif

  CefString(&settings.cache_path) =
      g_command_line->GetSwitchValue("cache-path");

  // Retrieve command-line proxy configuration, if any.
  bool has_proxy = false;
  cef_proxy_type_t proxy_type = PROXY_TYPE_DIRECT;
  CefString proxy_config;

  if (g_command_line->HasSwitch("proxy-type")) {
    std::string str = g_command_line->GetSwitchValue("proxy-type");
    if (str == "direct") {
      has_proxy = true;
      proxy_type = PROXY_TYPE_DIRECT;
    } else if (str == "named" ||
               str == "pac") {
      proxy_config = g_command_line->GetSwitchValue("proxy-config");
      if (!proxy_config.empty()) {
        has_proxy = true;
        proxy_type = (str == "named"?
                      PROXY_TYPE_NAMED:PROXY_TYPE_PAC_STRING);
      }
    }
  }

  if (has_proxy) {
    // Provide a ClientApp instance to handle proxy resolution.
    app->SetProxyConfig(proxy_type, proxy_config);
  }
}

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings) {
  ASSERT(g_command_line.get());
  if (!g_command_line.get())
    return;

  settings.remote_fonts_disabled = g_command_line->HasSwitch("remote-fonts-disabled");

  CefString(&settings.default_encoding) = g_command_line->GetSwitchValue("default-encoding");
  settings.encoding_detector_enabled = g_command_line->HasSwitch("encoding-detector-enabled");
  settings.javascript_disabled = g_command_line->HasSwitch("javascript-disabled");
  settings.javascript_open_windows_disallowed = g_command_line->HasSwitch("javascript-open-windows-disallowed");
  settings.javascript_close_windows_disallowed = g_command_line->HasSwitch("javascript-close-windows-disallowed");
  settings.javascript_access_clipboard_disallowed = g_command_line->HasSwitch("javascript-access-clipboard-disallowed");
  settings.dom_paste_disabled = g_command_line->HasSwitch("dom-paste-disabled");
  settings.caret_browsing_enabled = g_command_line->HasSwitch("caret-browsing-enabled");
  settings.java_disabled = g_command_line->HasSwitch("java-disabled");
  settings.plugins_disabled = g_command_line->HasSwitch("plugins-disabled");
  settings.universal_access_from_file_urls_allowed = g_command_line->HasSwitch("universal-access-from-file-urls-allowed");
  settings.file_access_from_file_urls_allowed = g_command_line->HasSwitch("file-access-from-file-urls-allowed");
  settings.web_security_disabled = g_command_line->HasSwitch("web-security-disabled");
  settings.xss_auditor_enabled = g_command_line->HasSwitch("xss-auditor-enabled");
  settings.image_load_disabled = g_command_line->HasSwitch("image-load-disabled");
  settings.shrink_standalone_images_to_fit = g_command_line->HasSwitch("shrink-standalone-images-to-fit");
  settings.site_specific_quirks_disabled = g_command_line->HasSwitch("site-specific-quirks-disabled");
  settings.text_area_resize_disabled = g_command_line->HasSwitch("text-area-resize-disabled");
  settings.page_cache_disabled = g_command_line->HasSwitch("page-cache-disabled");
  settings.tab_to_links_disabled = g_command_line->HasSwitch("tab-to-links-disabled");
  settings.hyperlink_auditing_disabled = g_command_line->HasSwitch("hyperlink-auditing-disabled");
  settings.user_style_sheet_enabled = g_command_line->HasSwitch("user-style-sheet-enabled");

  CefString(&settings.user_style_sheet_location) = g_command_line->GetSwitchValue("user-style-sheet-location");
  settings.author_and_user_styles_disabled = g_command_line->HasSwitch("author-and-user-styles-disabled");
  settings.local_storage_disabled = g_command_line->HasSwitch("local-storage-disabled");
  settings.databases_disabled = g_command_line->HasSwitch("databases-disabled");
  settings.application_cache_disabled = g_command_line->HasSwitch("application-cache-disabled");
  settings.webgl_disabled = g_command_line->HasSwitch("webgl-disabled");
  settings.accelerated_compositing_disabled = g_command_line->HasSwitch("accelerated-compositing-disabled");
  settings.accelerated_layers_disabled = g_command_line->HasSwitch("accelerated-layers-disabled");
  settings.accelerated_video_disabled = g_command_line->HasSwitch("accelerated-video-disabled");
  settings.accelerated_2d_canvas_disabled = g_command_line->HasSwitch("accelerated-2d-canvas-disabled");
  settings.accelerated_painting_enabled = g_command_line->HasSwitch("accelerated-painting-enabled");
  settings.accelerated_filters_enabled = g_command_line->HasSwitch("accelerated-filters-enabled");
  settings.accelerated_plugins_disabled = g_command_line->HasSwitch("accelerated-plugins-disabled");
  settings.developer_tools_disabled = g_command_line->HasSwitch("developer-tools-disabled");
  settings.fullscreen_enabled = g_command_line->HasSwitch("fullscreen-enabled");
}
