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

#ifndef CEF_INCLUDE_CEF_REQUEST_HANDLER_H_
#define CEF_INCLUDE_CEF_REQUEST_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_cookie.h"
#include "include/cef_frame.h"
#include "include/cef_resource_handler.h"
#include "include/cef_response.h"
#include "include/cef_request.h"

///
// Callback interface used for asynchronous continuation of authentication
// requests.
///
/*--cef(source=library)--*/
class CefAuthCallback : public virtual CefBase {
 public:
  ///
  // Continue the authentication request.
  ///
  /*--cef(capi_name=cont)--*/
  virtual void Continue(const CefString& username,
                        const CefString& password) =0;

  ///
  // Cancel the authentication request.
  ///
  /*--cef()--*/
  virtual void Cancel() =0;
};


///
// Implement this interface to handle events related to browser requests. The
// methods of this class will be called on the thread indicated.
///
/*--cef(source=client)--*/
class CefRequestHandler : public virtual CefBase {
 public:
  ///
  // Called on the IO thread before a resource request is loaded. The |request|
  // object may be modified. To cancel the request return true otherwise return
  // false.
  ///
  /*--cef()--*/
  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request) {
    return false;
  }

  ///
  // Called on the IO thread before a resource is loaded. To allow the resource
  // to load normally return NULL. To specify a handler for the resource return
  // a CefResourceHandler object. The |request| object should not be modified in
  // this callback.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefResourceHandler> GetResourceHandler(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      CefRefPtr<CefRequest> request) {
    return NULL;
  }

  ///
  // Called on the IO thread when a resource load is redirected. The |old_url|
  // parameter will contain the old URL. The |new_url| parameter will contain
  // the new URL and can be changed if desired.
  ///
  /*--cef()--*/
  virtual void OnResourceRedirect(CefRefPtr<CefBrowser> browser,
                                  CefRefPtr<CefFrame> frame,
                                  const CefString& old_url,
                                  CefString& new_url) {}

  ///
  // Called on the IO thread when the browser needs credentials from the user.
  // |isProxy| indicates whether the host is a proxy server. |host| contains the
  // hostname and |port| contains the port number. Return true to continue the
  // request and call CefAuthCallback::Complete() when the authentication
  // information is available. Return false to cancel the request.
  ///
  /*--cef(optional_param=realm)--*/
  virtual bool GetAuthCredentials(CefRefPtr<CefBrowser> browser,
                                  CefRefPtr<CefFrame> frame,
                                  bool isProxy,
                                  const CefString& host,
                                  int port,
                                  const CefString& realm,
                                  const CefString& scheme,
                                  CefRefPtr<CefAuthCallback> callback) {
    return false;
  }

  ///
  // Called on the IO thread to retrieve the cookie manager. |main_url| is the
  // URL of the top-level frame. Cookies managers can be unique per browser or
  // shared across multiple browsers. The global cookie manager will be used if
  // this method returns NULL.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefCookieManager> GetCookieManager(
      CefRefPtr<CefBrowser> browser,
      const CefString& main_url) { return NULL; }

  ///
  // Called on the UI thread to handle requests for URLs with an unknown
  // protocol component. Set |allow_os_execution| to true to attempt execution
  // via the registered OS protocol handler, if any.
  // SECURITY WARNING: YOU SHOULD USE THIS METHOD TO ENFORCE RESTRICTIONS BASED
  // ON SCHEME, HOST OR OTHER URL ANALYSIS BEFORE ALLOWING OS EXECUTION.
  ///
  /*--cef()--*/
  virtual void OnProtocolExecution(CefRefPtr<CefBrowser> browser,
                                   const CefString& url,
                                   bool& allow_os_execution) {}
};

#endif  // CEF_INCLUDE_CEF_REQUEST_HANDLER_H_
