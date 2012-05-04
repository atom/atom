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

#ifndef CEF_INCLUDE_CEF_DISPLAY_HANDLER_H_
#define CEF_INCLUDE_CEF_DISPLAY_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"

///
// Implement this interface to handle events related to browser display state.
// The methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefDisplayHandler : public virtual CefBase {
 public:
  typedef cef_handler_statustype_t StatusType;

  ///
  // Called when the navigation state has changed.
  ///
  /*--cef()--*/
  virtual void OnNavStateChange(CefRefPtr<CefBrowser> browser,
                                bool canGoBack,
                                bool canGoForward) {}

  ///
  // Called when a frame's address has changed.
  ///
  /*--cef()--*/
  virtual void OnAddressChange(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefFrame> frame,
                               const CefString& url) {}

  ///
  // Called when the size of the content area has changed.
  ///
  /*--cef()--*/
  virtual void OnContentsSizeChange(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    int width,
                                    int height) {}

  ///
  // Called when the page title changes.
  ///
  /*--cef(optional_param=title)--*/
  virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
                             const CefString& title) {}

  ///
  // Called when the browser is about to display a tooltip. |text| contains the
  // text that will be displayed in the tooltip. To handle the display of the
  // tooltip yourself return true. Otherwise, you can optionally modify |text|
  // and then return false to allow the browser to display the tooltip.
  ///
  /*--cef(optional_param=text)--*/
  virtual bool OnTooltip(CefRefPtr<CefBrowser> browser,
                         CefString& text) { return false; }

  ///
  // Called when the browser receives a status message. |text| contains the text
  // that will be displayed in the status message and |type| indicates the
  // status message type.
  ///
  /*--cef(optional_param=value)--*/
  virtual void OnStatusMessage(CefRefPtr<CefBrowser> browser,
                               const CefString& value,
                               StatusType type) {}

  ///
  // Called to display a console message. Return true to stop the message from
  // being output to the console.
  ///
  /*--cef(optional_param=message,optional_param=source)--*/
  virtual bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                const CefString& message,
                                const CefString& source,
                                int line) { return false; }
};

#endif  // CEF_INCLUDE_CEF_DISPLAY_HANDLER_H_
