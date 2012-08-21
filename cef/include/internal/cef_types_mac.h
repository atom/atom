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

// Handle types.
#ifdef __cplusplus
#ifdef __OBJC__
@class NSCursor;
@class NSEvent;
@class NSView;
#else
class NSCursor;
class NSEvent;
struct NSView;
#endif
#define cef_cursor_handle_t NSCursor*
#define cef_event_handle_t NSEvent*
#define cef_window_handle_t NSView*
#else
#define cef_cursor_handle_t void*
#define cef_event_handle_t void*
#define cef_window_handle_t void*
#endif

#ifdef __cplusplus
extern "C" {
#endif

///
// Structure representing CefExecuteProcess arguments.
///
typedef struct _cef_main_args_t {
  int argc;
  char** argv;
} cef_main_args_t;

///
// Class representing window information.
///
typedef struct _cef_window_info_t {
  cef_string_t window_name;
  int x;
  int y;
  int width;
  int height;
  int hidden;

  // NSView pointer for the parent view.
  cef_window_handle_t parent_view;

  // NSView pointer for the new browser view.
  cef_window_handle_t view;
} cef_window_info_t;

#ifdef __cplusplus
}
#endif

#endif  // OS_MACOSX

#endif  // CEF_INCLUDE_INTERNAL_CEF_TYPES_MAC_H_
