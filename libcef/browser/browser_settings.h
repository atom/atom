// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_BROWSER_SETTINGS_H_
#define CEF_LIBCEF_BROWSER_BROWSER_SETTINGS_H_
#pragma once

#include "include/internal/cef_types_wrappers.h"

namespace webkit_glue {
struct WebPreferences;
}

void BrowserToWebSettings(const CefBrowserSettings& cef,
                          webkit_glue::WebPreferences& web);

#endif  // CEF_LIBCEF_BROWSER_BROWSER_SETTINGS_H_
