// Copyright (c) 2011 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#ifndef CEF_INCLUDE_CEF_NPLUGIN_H_
#define CEF_INCLUDE_CEF_NPLUGIN_H_
#pragma once

#include "internal/cef_nplugin_types.h"

///
// Netscape plugins are normally built at separate DLLs that are loaded by the
// browser when needed.  This interface supports the creation of plugins that
// are an embedded component of the application.  Embedded plugins built using
// this interface use the same Netscape Plugin API as DLL-based plugins.
// See https://developer.mozilla.org/En/Gecko_Plugin_API_Reference for complete
// documentation on how to use the Netscape Plugin API.
//
// This class provides attribute information and entry point functions for a
// plugin.
///
class CefPluginInfo : public cef_plugin_info_t {
 public:
  CefPluginInfo() {
    Init();
  }
  virtual ~CefPluginInfo() {
    Reset();
  }

  CefPluginInfo(const CefPluginInfo& r) {  // NOLINT(runtime/explicit)
    Init();
    *this = r;
  }
  CefPluginInfo(const cef_plugin_info_t& r) {  // NOLINT(runtime/explicit)
    Init();
    *this = r;
  }

  void Reset() {
    cef_string_clear(&unique_name);
    cef_string_clear(&display_name);
    cef_string_clear(&version);
    cef_string_clear(&description);
    cef_string_clear(&mime_types);
    cef_string_clear(&file_extensions);
    cef_string_clear(&type_descriptions);
    Init();
  }

  void Attach(const cef_plugin_info_t& r) {
    Reset();
    *static_cast<cef_plugin_info_t*>(this) = r;
  }

  void Detach() {
    Init();
  }

  CefPluginInfo& operator=(const CefPluginInfo& r) {
    return operator=(static_cast<const cef_plugin_info_t&>(r));
  }

  CefPluginInfo& operator=(const cef_plugin_info_t& r) {
    cef_string_copy(r.unique_name.str, r.unique_name.length, &unique_name);
    cef_string_copy(r.display_name.str, r.display_name.length, &display_name);
    cef_string_copy(r.version.str, r.version.length, &version);
    cef_string_copy(r.description.str, r.description.length, &description);
    cef_string_copy(r.mime_types.str, r.mime_types.length, &mime_types);
    cef_string_copy(r.file_extensions.str, r.file_extensions.length,
        &file_extensions);
    cef_string_copy(r.type_descriptions.str, r.type_descriptions.length,
        &type_descriptions);
#if !defined(OS_POSIX) || defined(OS_MACOSX)
    np_getentrypoints = r.np_getentrypoints;
#endif
    np_initialize = r.np_initialize;
    np_shutdown = r.np_shutdown;
    return *this;
  }

 protected:
  void Init() {
    memset(static_cast<cef_plugin_info_t*>(this), 0, sizeof(cef_plugin_info_t));
  }
};

///
// Register a plugin with the system.
///
bool CefRegisterPlugin(const CefPluginInfo& plugin_info);

#endif  // CEF_INCLUDE_CEF_NPLUGIN_H_
