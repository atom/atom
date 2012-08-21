// Copyright (c) 2008 Marshall A. Greenblatt. All rights reserved.
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


#ifndef CEF_INCLUDE_INTERNAL_CEF_WIN_H_
#define CEF_INCLUDE_INTERNAL_CEF_WIN_H_
#pragma once

#if defined(OS_WIN)
#include <windows.h>
#include "include/internal/cef_types_win.h"
#include "include/internal/cef_types_wrappers.h"

///
// Atomic increment and decrement.
///
#define CefAtomicIncrement(p) InterlockedIncrement(p)
#define CefAtomicDecrement(p) InterlockedDecrement(p)

///
// Critical section wrapper.
///
class CefCriticalSection {
 public:
  CefCriticalSection() {
    memset(&m_sec, 0, sizeof(CRITICAL_SECTION));
    InitializeCriticalSection(&m_sec);
  }
  virtual ~CefCriticalSection() {
    DeleteCriticalSection(&m_sec);
  }
  void Lock() {
    EnterCriticalSection(&m_sec);
  }
  void Unlock() {
    LeaveCriticalSection(&m_sec);
  }

  CRITICAL_SECTION m_sec;
};

///
// Handle types.
///
#define CefCursorHandle cef_cursor_handle_t
#define CefEventHandle cef_event_handle_t
#define CefWindowHandle cef_window_handle_t

struct CefMainArgsTraits {
  typedef cef_main_args_t struct_type;

  static inline void init(struct_type* s) {}
  static inline void clear(struct_type* s) {}

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    target->instance = src->instance;
  }
};

// Class representing CefExecuteProcess arguments.
class CefMainArgs : public CefStructBase<CefMainArgsTraits> {
 public:
  typedef CefStructBase<CefMainArgsTraits> parent;

  CefMainArgs() : parent() {}
  explicit CefMainArgs(const cef_main_args_t& r) : parent(r) {}
  explicit CefMainArgs(const CefMainArgs& r) : parent(r) {}
  explicit CefMainArgs(HINSTANCE hInstance) : parent() {
    instance = hInstance;
  }
};

struct CefWindowInfoTraits {
  typedef cef_window_info_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s) {
    cef_string_clear(&s->window_name);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    target->ex_style = src->ex_style;
    cef_string_set(src->window_name.str, src->window_name.length,
        &target->window_name, copy);
    target->style = src->style;
    target->x = src->x;
    target->y = src->y;
    target->width = src->width;
    target->height = src->height;
    target->parent_window = src->parent_window;
    target->menu = src->menu;
    target->window = src->window;
    target->transparent_painting = src->transparent_painting;
  }
};

///
// Class representing window information.
///
class CefWindowInfo : public CefStructBase<CefWindowInfoTraits> {
 public:
  typedef CefStructBase<CefWindowInfoTraits> parent;

  CefWindowInfo() : parent() {}
  explicit CefWindowInfo(const cef_window_info_t& r) : parent(r) {}
  explicit CefWindowInfo(const CefWindowInfo& r) : parent(r) {}

  void SetAsChild(HWND hWndParent, RECT windowRect) {
    style = WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_TABSTOP |
            WS_VISIBLE;
    parent_window = hWndParent;
    x = windowRect.left;
    y = windowRect.top;
    width = windowRect.right - windowRect.left;
    height = windowRect.bottom - windowRect.top;
  }

  void SetAsPopup(HWND hWndParent, const CefString& windowName) {
    style = WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_CLIPSIBLINGS |
            WS_VISIBLE;
    parent_window = hWndParent;
    x = CW_USEDEFAULT;
    y = CW_USEDEFAULT;
    width = CW_USEDEFAULT;
    height = CW_USEDEFAULT;

    cef_string_copy(windowName.c_str(), windowName.length(), &window_name);
  }

  void SetTransparentPainting(BOOL transparentPainting) {
    transparent_painting = transparentPainting;
  }
};

#endif  // OS_WIN

#endif  // CEF_INCLUDE_INTERNAL_CEF_WIN_H_
