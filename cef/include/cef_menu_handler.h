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

#ifndef CEF_INCLUDE_CEF_MENU_HANDLER_H_
#define CEF_INCLUDE_CEF_MENU_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"

///
// Implement this interface to handle events related to browser context menus.
// The methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefMenuHandler : public virtual CefBase {
 public:
  typedef cef_menu_id_t MenuId;

  ///
  // Called before a context menu is displayed. Return false to display the
  // default context menu or true to cancel the display.
  ///
  /*--cef()--*/
  virtual bool OnBeforeMenu(CefRefPtr<CefBrowser> browser,
                            const CefMenuInfo& menuInfo) { return false; }

  ///
  // Called to optionally override the default text for a context menu item.
  // |label| contains the default text and may be modified to substitute
  // alternate text.
  ///
  /*--cef()--*/
  virtual void GetMenuLabel(CefRefPtr<CefBrowser> browser,
                            MenuId menuId,
                            CefString& label) {}

  ///
  // Called when an option is selected from the default context menu. Return
  // false to execute the default action or true to cancel the action.
  ///
  /*--cef()--*/
  virtual bool OnMenuAction(CefRefPtr<CefBrowser> browser,
                            MenuId menuId) { return false; }
};

#endif  // CEF_INCLUDE_CEF_MENU_HANDLER_H_
