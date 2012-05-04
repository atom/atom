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


#ifndef CEF_INCLUDE_INTERNAL_CEF_NPLUGIN_TYPES_H_
#define CEF_INCLUDE_INTERNAL_CEF_NPLUGIN_TYPES_H_
#pragma once

#include "include/internal/cef_export.h"
#include "include/internal/cef_string.h"
// Include path modified for CEF Binary Distribution.
#include "include/internal/npapi/npapi.h"
// Include path modified for CEF Binary Distribution.
#include "include/internal/npapi/nphostapi.h"

#ifdef __cplusplus
extern "C" {
#endif

// Netscape plugins are normally built at separate DLLs that are loaded by the
// browser when needed.  This interface supports the creation of plugins that
// are an embedded component of the application.  Embedded plugins built using
// this interface use the same Netscape Plugin API as DLL-based plugins.
// See https://developer.mozilla.org/En/Gecko_Plugin_API_Reference for complete
// documentation on how to use the Netscape Plugin API.

// This structure provides attribute information and entry point functions for
// a plugin.
typedef struct _cef_plugin_info_t {
  // The unique name that identifies the plugin.
  cef_string_t unique_name;

  // The friendly display name of the plugin.
  cef_string_t display_name;

  // The version string of the plugin.
  cef_string_t version;

  // A description of the plugin.
  cef_string_t description;

  // A pipe (|) delimited list of mime type values that the plugin supports.
  cef_string_t mime_types;

  // A pipe (|) delimited list of extension values. Each value is associated
  // with the mime type value at the same position. Multiple file extensions
  // for the same mime type may be delimited with commas (,).
  cef_string_t file_extensions;

  // A pipe (|) delimited list of description values. Each value is associated
  // with the mime type value at the same position.
  cef_string_t type_descriptions;

  // Entry point function pointers.
#if !defined(OS_POSIX) || defined(OS_MACOSX)
  NP_GetEntryPointsFunc np_getentrypoints;
#endif
  NP_InitializeFunc np_initialize;
  NP_ShutdownFunc np_shutdown;
} cef_plugin_info_t;

#ifdef __cplusplus
}
#endif

#endif  // CEF_INCLUDE_INTERNAL_CEF_NPLUGIN_TYPES_H_
