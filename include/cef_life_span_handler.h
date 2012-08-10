// Copyright (c) 2012 Marshall A. Greenblatt. All rights reserved.
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

#ifndef CEF_INCLUDE_CEF_LIFE_SPAN_HANDLER_H_
#define CEF_INCLUDE_CEF_LIFE_SPAN_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"

class CefClient;

///
// Implement this interface to handle events related to browser life span. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefLifeSpanHandler : public virtual CefBase {
 public:
  ///
  // Called before a new popup window is created. The |parentBrowser| parameter
  // will point to the parent browser window. The |popupFeatures| parameter will
  // contain information about the style of popup window requested. Return false
  // to have the framework create the new popup window based on the parameters
  // in |windowInfo|. Return true to cancel creation of the popup window. By
  // default, a newly created popup window will have the same client and
  // settings as the parent window. To change the client for the new window
  // modify the object that |client| points to. To change the settings for the
  // new window modify the |settings| structure.
  ///
  /*--cef(optional_param=url)--*/
  virtual bool OnBeforePopup(CefRefPtr<CefBrowser> parentBrowser,
                             const CefPopupFeatures& popupFeatures,
                             CefWindowInfo& windowInfo,
                             const CefString& url,
                             CefRefPtr<CefClient>& client,
                             CefBrowserSettings& settings) { return false; }

  ///
  // Called after a new window is created.
  ///
  /*--cef()--*/
  virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) {}

  ///
  // Called when a modal window is about to display and the modal loop should
  // begin running. Return false to use the default modal loop implementation or
  // true to use a custom implementation.
  ///
  /*--cef()--*/
  virtual bool RunModal(CefRefPtr<CefBrowser> browser) { return false; }

  ///
  // Called when a window has recieved a request to close. Return false to
  // proceed with the window close or true to cancel the window close. If this
  // is a modal window and a custom modal loop implementation was provided in
  // RunModal() this callback should be used to restore the opener window to a
  // usable state.
  ///
  /*--cef()--*/
  virtual bool DoClose(CefRefPtr<CefBrowser> browser) { return false; }

  ///
  // Called just before a window is closed. If this is a modal window and a
  // custom modal loop implementation was provided in RunModal() this callback
  // should be used to exit the custom modal loop.
  ///
  /*--cef()--*/
  virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) {}
};

#endif  // CEF_INCLUDE_CEF_LIFE_SPAN_HANDLER_H_
