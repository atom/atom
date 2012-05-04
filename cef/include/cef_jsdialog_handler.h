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

#ifndef CEF_INCLUDE_CEF_JSDIALOG_HANDLER_H_
#define CEF_INCLUDE_CEF_JSDIALOG_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"

///
// Implement this interface to handle events related to JavaScript dialogs. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefJSDialogHandler : public virtual CefBase {
 public:
  ///
  // Called  to run a JavaScript alert message. Return false to display the
  // default alert or true if you displayed a custom alert.
  ///
  /*--cef()--*/
  virtual bool OnJSAlert(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         const CefString& message) { return false; }

  ///
  // Called to run a JavaScript confirm request. Return false to display the
  // default alert or true if you displayed a custom alert. If you handled the
  // alert set |retval| to true if the user accepted the confirmation.
  ///
  /*--cef()--*/
  virtual bool OnJSConfirm(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           const CefString& message,
                           bool& retval) { return false; }

  ///
  // Called to run a JavaScript prompt request. Return false to display the
  // default prompt or true if you displayed a custom prompt. If you handled
  // the prompt set |retval| to true if the user accepted the prompt and request
  // and |result| to the resulting value.
  ///
  /*--cef()--*/
  virtual bool OnJSPrompt(CefRefPtr<CefBrowser> browser,
                          CefRefPtr<CefFrame> frame,
                          const CefString& message,
                          const CefString& defaultValue,
                          bool& retval,
                          CefString& result) { return false; }
};

#endif  // CEF_INCLUDE_CEF_JSDIALOG_HANDLER_H_
