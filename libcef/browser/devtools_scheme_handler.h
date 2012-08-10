// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_DEVTOOLS_SCHEME_HANDLER_H_
#define CEF_LIBCEF_BROWSER_DEVTOOLS_SCHEME_HANDLER_H_
#pragma once

extern const char kChromeDevToolsScheme[];
extern const char kChromeDevToolsHost[];
extern const char kChromeDevToolsURL[];

// Register the DevTools scheme handler.
void RegisterDevToolsSchemeHandler();

#endif  // CEF_LIBCEF_BROWSER_DEVTOOLS_SCHEME_HANDLER_H_
