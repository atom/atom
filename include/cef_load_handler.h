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

#ifndef CEF_INCLUDE_CEF_LOAD_HANDLER_H_
#define CEF_INCLUDE_CEF_LOAD_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"

///
// Implement this interface to handle events related to browser load status. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefLoadHandler : public virtual CefBase {
 public:
  typedef cef_errorcode_t ErrorCode;
  typedef cef_termination_status_t TerminationStatus;

  ///
  // Called when the browser begins loading a frame. The |frame| value will
  // never be empty -- call the IsMain() method to check if this frame is the
  // main frame. Multiple frames may be loading at the same time. Sub-frames may
  // start or continue loading after the main frame load has ended. This method
  // may not be called for a particular frame if the load request for that frame
  // fails.
  ///
  /*--cef()--*/
  virtual void OnLoadStart(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame) {}

  ///
  // Called when the browser is done loading a frame. The |frame| value will
  // never be empty -- call the IsMain() method to check if this frame is the
  // main frame. Multiple frames may be loading at the same time. Sub-frames may
  // start or continue loading after the main frame load has ended. This method
  // will always be called for all frames irrespective of whether the request
  // completes successfully.
  ///
  /*--cef()--*/
  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) {}

  ///
  // Called when the browser fails to load a resource. |errorCode| is the error
  // code number, |errorText| is the error text and and |failedUrl| is the URL
  // that failed to load. See net\base\net_error_list.h for complete
  // descriptions of the error codes.
  ///
  /*--cef(optional_param=errorText)--*/
  virtual void OnLoadError(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           ErrorCode errorCode,
                           const CefString& errorText,
                           const CefString& failedUrl) {}

  ///
  // Called when the render process terminates unexpectedly. |status| indicates
  // how the process terminated.
  ///
  /*--cef()--*/
  virtual void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
                                         TerminationStatus status) {}

  ///
  // Called when a plugin has crashed. |plugin_path| is the path of the plugin
  // that crashed.
  ///
  /*--cef()--*/
  virtual void OnPluginCrashed(CefRefPtr<CefBrowser> browser,
                               const CefString& plugin_path) {}
};

#endif  // CEF_INCLUDE_CEF_LOAD_HANDLER_H_
