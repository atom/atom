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

#ifndef CEF_INCLUDE_CEF_JSDIALOG_HANDLER_H_
#define CEF_INCLUDE_CEF_JSDIALOG_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"

///
// Callback interface used for asynchronous continuation of JavaScript dialog
// requests.
///
/*--cef(source=library)--*/
class CefJSDialogCallback : public virtual CefBase {
 public:
  ///
  // Continue the JS dialog request. Set |success| to true if the OK button was
  // pressed. The |user_input| value should be specified for prompt dialogs.
  ///
  /*--cef(capi_name=cont,optional_param=user_input)--*/
  virtual void Continue(bool success,
                        const CefString& user_input) =0;
};


///
// Implement this interface to handle events related to JavaScript dialogs. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefJSDialogHandler : public virtual CefBase {
 public:
  typedef cef_jsdialog_type_t JSDialogType;

  ///
  // Called to run a JavaScript dialog. The |default_prompt_text| value will be
  // specified for prompt dialogs only. Set |suppress_message| to true and
  // return false to suppress the message (suppressing messages is preferable
  // to immediately executing the callback as this is used to detect presumably
  // malicious behavior like spamming alert messages in onbeforeunload). Set
  // |suppress_message| to false and return false to use the default
  // implementation (the default implementation will show one modal dialog at a
  // time and suppress any additional dialog requests until the displayed dialog
  // is dismissed). Return true if the application will use a custom dialog or
  // if the callback has been executed immediately. Custom dialogs may be either
  // modal or modeless. If a custom dialog is used the application must execute
  // |callback| once the custom dialog is dismissed.
  ///
  /*--cef(optional_param=accept_lang,optional_param=message_text,
          optional_param=default_prompt_text)--*/
  virtual bool OnJSDialog(CefRefPtr<CefBrowser> browser,
                          const CefString& origin_url,
                          const CefString& accept_lang,
                          JSDialogType dialog_type,
                          const CefString& message_text,
                          const CefString& default_prompt_text,
                          CefRefPtr<CefJSDialogCallback> callback,
                          bool& suppress_message) {
    return false;
  }

  ///
  // Called to run a dialog asking the user if they want to leave a page. Return
  // false to use the default dialog implementation. Return true if the
  // application will use a custom dialog or if the callback has been executed
  // immediately. Custom dialogs may be either modal or modeless. If a custom
  // dialog is used the application must execute |callback| once the custom
  // dialog is dismissed.
  ///
  /*--cef(optional_param=message_text)--*/
  virtual bool OnBeforeUnloadDialog(CefRefPtr<CefBrowser> browser,
                                    const CefString& message_text,
                                    bool is_reload,
                                    CefRefPtr<CefJSDialogCallback> callback) {
    return false;
  }

  ///
  // Called to cancel any pending dialogs and reset any saved dialog state. Will
  // be called due to events like page navigation irregardless of whether any
  // dialogs are currently pending.
  ///
  /*--cef()--*/
  virtual void OnResetDialogState(CefRefPtr<CefBrowser> browser) {}
};

#endif  // CEF_INCLUDE_CEF_JSDIALOG_HANDLER_H_
