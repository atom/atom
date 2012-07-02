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


#ifndef CEF_INCLUDE_INTERNAL_CEF_TYPES_MAC_H_
#define CEF_INCLUDE_INTERNAL_CEF_TYPES_MAC_H_
#pragma once

#include "include/internal/cef_build.h"

#if defined(OS_MACOSX)
#include "include/internal/cef_string.h"

// Window handle.
#ifdef __cplusplus
#ifdef __OBJC__
@class NSCursor;
@class NSView;
#else
class NSCursor;
class NSView;
#endif
#define cef_window_handle_t NSView*
#define cef_cursor_handle_t NSCursor*
#else
#define cef_window_handle_t void*
#define cef_cursor_handle_t void*
#endif

#ifdef __cplusplus
extern "C" {
#endif

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
  cef_string_t m_windowName;
  int m_x;
  int m_y;
  int m_nWidth;
  int m_nHeight;
  int m_bHidden;

  // NSView pointer for the parent view.
  cef_window_handle_t m_ParentView;

  // If window rendering is disabled no browser window will be created. Set
  // |m_ParentView| to the window that will act as the parent for popup menus,
  // dialog boxes, etc.
  int m_bWindowRenderingDisabled;

  // Set to true to enable transparent painting.
  int m_bTransparentPainting;

  // NSView pointer for the new browser view.
  cef_window_handle_t m_View;
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
  int keyCode;
  int character;
  int characterNoModifiers;
} cef_key_info_t;

#ifdef __cplusplus
}
#endif

#endif  // OS_MACOSX

#endif  // CEF_INCLUDE_INTERNAL_CEF_TYPES_MAC_H_
