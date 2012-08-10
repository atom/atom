// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <windows.h>
#include <commctrl.h>
#include <Objbase.h>

#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/browser_main.h"

#include "base/string_piece.h"
#include "base/win/resource_util.h"

void CefBrowserMainParts::PlatformInitialize() {
  HRESULT res;

  // Initialize common controls.
  res = CoInitialize(NULL);
  DCHECK(SUCCEEDED(res));
  INITCOMMONCONTROLSEX InitCtrlEx;
  InitCtrlEx.dwSize = sizeof(INITCOMMONCONTROLSEX);
  InitCtrlEx.dwICC  = ICC_STANDARD_CLASSES;
  InitCommonControlsEx(&InitCtrlEx);

  // Start COM stuff.
  res = OleInitialize(NULL);
  DCHECK(SUCCEEDED(res));

  // Register the browser window class.
  CefBrowserHostImpl::RegisterWindowClass();
}

void CefBrowserMainParts::PlatformCleanup() {
}
