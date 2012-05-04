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
//
// ---------------------------------------------------------------------------
//
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//

#ifndef CEF_INCLUDE_CEF_CLIENT_H_
#define CEF_INCLUDE_CEF_CLIENT_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_display_handler.h"
#include "include/cef_drag_handler.h"
#include "include/cef_find_handler.h"
#include "include/cef_focus_handler.h"
#include "include/cef_jsdialog_handler.h"
#include "include/cef_keyboard_handler.h"
#include "include/cef_life_span_handler.h"
#include "include/cef_load_handler.h"
#include "include/cef_menu_handler.h"
#include "include/cef_permission_handler.h"
#include "include/cef_print_handler.h"
#include "include/cef_render_handler.h"
#include "include/cef_request_handler.h"
#include "include/cef_v8context_handler.h"

///
// Implement this interface to provide handler implementations.
///
/*--cef(source=client,no_debugct_check)--*/
class CefClient : public virtual CefBase {
 public:
  ///
  // Return the handler for browser life span events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() {
    return NULL;
  }

  ///
  // Return the handler for browser load status events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefLoadHandler> GetLoadHandler() {
    return NULL;
  }

  ///
  // Return the handler for browser request events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefRequestHandler> GetRequestHandler() {
    return NULL;
  }

  ///
  // Return the handler for browser display state events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() {
    return NULL;
  }

  ///
  // Return the handler for focus events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFocusHandler> GetFocusHandler() {
    return NULL;
  }

  ///
  // Return the handler for keyboard events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() {
    return NULL;
  }

  ///
  // Return the handler for context menu events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefMenuHandler> GetMenuHandler() {
    return NULL;
  }

  ///
  // Return the handler for browser permission events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefPermissionHandler> GetPermissionHandler() {
    return NULL;
  }

  ///
  // Return the handler for printing events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefPrintHandler> GetPrintHandler() {
    return NULL;
  }

  ///
  // Return the handler for find result events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFindHandler> GetFindHandler() {
    return NULL;
  }

  ///
  // Return the handler for JavaScript dialog events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefJSDialogHandler> GetJSDialogHandler() {
    return NULL;
  }

  ///
  // Return the handler for V8 context events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8ContextHandler> GetV8ContextHandler() {
    return NULL;
  }

  ///
  // Return the handler for off-screen rendering events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefRenderHandler> GetRenderHandler() {
    return NULL;
  }

  ///
  // Return the handler for drag events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDragHandler> GetDragHandler() {
    return NULL;
  }
};

#endif  // CEF_INCLUDE_CEF_CLIENT_H_
