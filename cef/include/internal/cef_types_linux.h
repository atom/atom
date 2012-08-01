// Copyright (c) 2010 Marshall A. Greenblatt. All rights reserved.
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


#ifndef CEF_INCLUDE_INTERNAL_CEF_TYPES_LINUX_H_
#define CEF_INCLUDE_INTERNAL_CEF_TYPES_LINUX_H_
#pragma once

#include "include/internal/cef_build.h"

#if defined(OS_LINUX)
#include <gtk/gtk.h>
#include "include/internal/cef_string.h"

#ifdef __cplusplus
extern "C" {
#endif

// Window handle.
#define cef_window_handle_t GtkWidget*
#define cef_cursor_handle_t void*

///
// Supported graphics implementations.
///
enum cef_graphics_implementation_t {
  DESKTOP_IN_PROCESS = 0,
  DESKTOP_IN_PROCESS_COMMAND_BUFFER,
};

///
// Class representing window information.
///
typedef struct _cef_window_info_t {
  // Pointer for the parent GtkBox widget.
  cef_window_handle_t m_ParentWidget;

  // Pointer for the new browser widget.
  cef_window_handle_t m_Widget;
} cef_window_info_t;

///
// Class representing print context information.
///
typedef struct _cef_print_info_t {
  double m_Scale;
} cef_print_info_t;

///
// Class representing key information.
///
typedef struct _cef_key_info_t {
  int key;
} cef_key_info_t;

#ifdef __cplusplus
}
#endif

#endif  // OS_LINUX

#endif  // CEF_INCLUDE_INTERNAL_CEF_TYPES_LINUX_H_
