// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_nplugin.h"
#include "include/capi/cef_nplugin_capi.h"

bool CefRegisterPlugin(const CefPluginInfo& plugin_info) {
  return cef_register_plugin(&plugin_info)?true:false;
}
