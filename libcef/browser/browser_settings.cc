// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/browser_settings.h"

#include <string>

#include "include/internal/cef_types_wrappers.h"

#include "base/file_path.h"
#include "base/utf_string_conversions.h"
#include "content/browser/gpu/gpu_process_host.h"
#include "content/public/browser/gpu_data_manager.h"
#include "webkit/glue/webpreferences.h"

using webkit_glue::WebPreferences;

void BrowserToWebSettings(const CefBrowserSettings& cef, WebPreferences& web) {
  if (cef.standard_font_family.length > 0) {
    web.standard_font_family_map[WebPreferences::kCommonScript] =
        CefString(&cef.standard_font_family);
  } else {
    web.standard_font_family_map[WebPreferences::kCommonScript] =
        ASCIIToUTF16("Times");
  }

  if (cef.fixed_font_family.length > 0) {
    web.fixed_font_family_map[WebPreferences::kCommonScript] =
        CefString(&cef.fixed_font_family);
  } else {
    web.fixed_font_family_map[WebPreferences::kCommonScript] =
        ASCIIToUTF16("Courier");
  }

  if (cef.serif_font_family.length > 0) {
    web.serif_font_family_map[WebPreferences::kCommonScript] =
        CefString(&cef.serif_font_family);
  } else {
    web.serif_font_family_map[WebPreferences::kCommonScript] =
        ASCIIToUTF16("Times");
  }

  if (cef.sans_serif_font_family.length > 0) {
    web.sans_serif_font_family_map[WebPreferences::kCommonScript] =
        CefString(&cef.sans_serif_font_family);
  } else {
    web.sans_serif_font_family_map[WebPreferences::kCommonScript] =
        ASCIIToUTF16("Helvetica");
  }

  // These two fonts below are picked from the intersection of
  // Win XP font list and Vista font list :
  //   http://www.microsoft.com/typography/fonts/winxp.htm
  //   http://blogs.msdn.com/michkap/archive/2006/04/04/567881.aspx
  // Some of them are installed only with CJK and complex script
  // support enabled on Windows XP and are out of consideration here.
  // (although we enabled both on our buildbots.)
  // They (especially Impact for fantasy) are not typical cursive
  // and fantasy fonts, but it should not matter for layout tests
  // as long as they're available.

  if (cef.cursive_font_family.length > 0) {
    web.cursive_font_family_map[WebPreferences::kCommonScript] =
        CefString(&cef.cursive_font_family);
  } else {
    web.cursive_font_family_map[WebPreferences::kCommonScript] =
#if defined(OS_MACOSX)
        ASCIIToUTF16("Apple Chancery");
#else
        ASCIIToUTF16("Comic Sans MS");
#endif
  }

  if (cef.fantasy_font_family.length > 0) {
    web.fantasy_font_family_map[WebPreferences::kCommonScript] =
        CefString(&cef.fantasy_font_family);
  } else {
    web.fantasy_font_family_map[WebPreferences::kCommonScript] =
#if defined(OS_MACOSX)
        ASCIIToUTF16("Papyrus");
#else
        ASCIIToUTF16("Impact");
#endif
  }

  if (cef.default_font_size > 0)
    web.default_font_size = cef.default_font_size;
  else
    web.default_font_size = 16;

  if (cef.default_fixed_font_size > 0)
    web.default_fixed_font_size = cef.default_fixed_font_size;
  else
    web.default_fixed_font_size = 13;

  if (cef.minimum_font_size > 0)
    web.minimum_font_size = cef.minimum_font_size;
  else
    web.minimum_font_size = 1;

  if (cef.minimum_logical_font_size > 0)
    web.minimum_logical_font_size = cef.minimum_logical_font_size;
  else
    web.minimum_logical_font_size = 9;

  if (cef.default_encoding.length > 0)
    web.default_encoding = CefString(&cef.default_encoding);
  else
    web.default_encoding = "ISO-8859-1";

  web.javascript_enabled = !cef.javascript_disabled;
  web.web_security_enabled = !cef.web_security_disabled;
  web.javascript_can_open_windows_automatically =
      !cef.javascript_open_windows_disallowed;
  web.loads_images_automatically = !cef.image_load_disabled;
  web.plugins_enabled = !cef.plugins_disabled;
  web.dom_paste_enabled = !cef.dom_paste_disabled;
  web.developer_extras_enabled = !cef.developer_tools_disabled;
  web.inspector_settings.clear();
  web.site_specific_quirks_enabled = !cef.site_specific_quirks_disabled;
  web.shrinks_standalone_images_to_fit = cef.shrink_standalone_images_to_fit;
  web.uses_universal_detector = cef.encoding_detector_enabled;
  web.text_areas_are_resizable = !cef.text_area_resize_disabled;
  web.java_enabled = !cef.java_disabled;
  web.allow_scripts_to_close_windows = !cef.javascript_close_windows_disallowed;
  web.uses_page_cache = !cef.page_cache_disabled;
  web.remote_fonts_enabled = !cef.remote_fonts_disabled;
  web.javascript_can_access_clipboard =
      !cef.javascript_access_clipboard_disallowed;
  web.xss_auditor_enabled = cef.xss_auditor_enabled;
  web.local_storage_enabled = !cef.local_storage_disabled;
  web.databases_enabled = !cef.databases_disabled;
  web.application_cache_enabled = !cef.application_cache_disabled;
  web.tabs_to_links = !cef.tab_to_links_disabled;
  web.caret_browsing_enabled = cef.caret_browsing_enabled;
  web.hyperlink_auditing_enabled = !cef.hyperlink_auditing_disabled;

  web.user_style_sheet_enabled = cef.user_style_sheet_enabled;

  if (cef.user_style_sheet_location.length > 0) {
    web.user_style_sheet_location =
        GURL(std::string(CefString(&cef.user_style_sheet_location)));
  }

  web.author_and_user_styles_enabled = !cef.author_and_user_styles_disabled;
  web.allow_universal_access_from_file_urls =
      cef.universal_access_from_file_urls_allowed;
  web.allow_file_access_from_file_urls = cef.file_access_from_file_urls_allowed;
  web.experimental_webgl_enabled =
      GpuProcessHost::gpu_enabled() && !cef.webgl_disabled;
  web.gl_multisampling_enabled = web.experimental_webgl_enabled;
  web.show_composited_layer_borders = false;
  web.accelerated_compositing_enabled =
      GpuProcessHost::gpu_enabled() && !cef.accelerated_compositing_disabled;
  web.accelerated_layers_enabled = !cef.accelerated_layers_disabled;
  web.accelerated_video_enabled = !cef.accelerated_video_disabled;
  web.accelerated_2d_canvas_enabled =
      GpuProcessHost::gpu_enabled() && !cef.accelerated_2d_canvas_disabled;
  web.accelerated_painting_enabled =
      GpuProcessHost::gpu_enabled() && cef.accelerated_painting_enabled;
  web.accelerated_filters_enabled =
      GpuProcessHost::gpu_enabled() && cef.accelerated_filters_enabled;
  web.accelerated_plugins_enabled = !cef.accelerated_plugins_disabled;
  web.memory_info_enabled = false;
  web.fullscreen_enabled = cef.fullscreen_enabled;

  // TODO(cef): The GPU black list will need to be initialized. See
  // InitializeGpuDataManager() in chrome/browser/chrome_browser_main.cc.
  {  // Certain GPU features might have been blacklisted.
    content::GpuDataManager* gpu_data_manager =
        content::GpuDataManager::GetInstance();
    DCHECK(gpu_data_manager);
    content::GpuFeatureType blacklist_flags =
        gpu_data_manager->GetGpuFeatureType();
    if (blacklist_flags & content::GPU_FEATURE_TYPE_ACCELERATED_COMPOSITING)
      web.accelerated_compositing_enabled = false;
    if (blacklist_flags & content::GPU_FEATURE_TYPE_WEBGL)
      web.experimental_webgl_enabled = false;
    if (blacklist_flags & content::GPU_FEATURE_TYPE_ACCELERATED_2D_CANVAS)
      web.accelerated_2d_canvas_enabled = false;
    if (blacklist_flags & content::GPU_FEATURE_TYPE_MULTISAMPLING)
      web.gl_multisampling_enabled = false;

    // Accelerated video is slower than regular when using a software 3d
    // rasterizer.
    if (gpu_data_manager->ShouldUseSoftwareRendering())
      web.accelerated_video_enabled = false;
  }
}
