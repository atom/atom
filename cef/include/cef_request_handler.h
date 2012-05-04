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
#include "include/cef_download_handler.h"
#include "include/cef_frame.h"
#include "include/cef_content_filter.h"
#include "include/cef_response.h"
#include "include/cef_request.h"
#include "include/cef_stream.h"

///
// Implement this interface to handle events related to browser requests. The
// methods of this class will be called on the thread indicated.
///
/*--cef(source=client)--*/
class CefRequestHandler : public virtual CefBase {
 public:
  typedef cef_handler_navtype_t NavType;

  ///
  // Called on the UI thread before browser navigation. Return true to cancel
  // the navigation or false to allow the navigation to proceed.
  ///
  /*--cef()--*/
  virtual bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                              CefRefPtr<CefFrame> frame,
                              CefRefPtr<CefRequest> request,
                              NavType navType,
                              bool isRedirect) { return false; }

  ///
  // Called on the IO thread before a resource is loaded.  To allow the resource
  // to load normally return false. To redirect the resource to a new url
  // populate the |redirectUrl| value and return false.  To specify data for the
  // resource return a CefStream object in |resourceStream|, use the |response|
  // object to set mime type, HTTP status code and optional header values, and
  // return false. To cancel loading of the resource return true. Any
  // modifications to |request| will be observed.  If the URL in |request| is
  // changed and |redirectUrl| is also set, the URL in |request| will be used.
  ///
  /*--cef()--*/
  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefRequest> request,
                                    CefString& redirectUrl,
                                    CefRefPtr<CefStreamReader>& resourceStream,
                                    CefRefPtr<CefResponse> response,
                                    int loadFlags) { return false; }

  ///
  // Called on the IO thread when a resource load is redirected. The |old_url|
  // parameter will contain the old URL. The |new_url| parameter will contain
  // the new URL and can be changed if desired.
  ///
  /*--cef()--*/
  virtual void OnResourceRedirect(CefRefPtr<CefBrowser> browser,
                                  const CefString& old_url,
                                  CefString& new_url) {}

  ///
  // Called on the UI thread after a response to the resource request is
  // received. Set |filter| if response content needs to be monitored and/or
  // modified as it arrives.
  ///
  /*--cef()--*/
  virtual void OnResourceResponse(CefRefPtr<CefBrowser> browser,
                                  const CefString& url,
                                  CefRefPtr<CefResponse> response,
                                  CefRefPtr<CefContentFilter>& filter) {}

  ///
  // Called on the IO thread to handle requests for URLs with an unknown
  // protocol component. Return true to indicate that the request should
  // succeed because it was handled externally. Set |allowOSExecution| to true
  // and return false to attempt execution via the registered OS protocol
  // handler, if any. If false is returned and either |allow_os_execution|
  // is false or OS protocol handler execution fails then the request will fail
  // with an error condition.
  // SECURITY WARNING: YOU SHOULD USE THIS METHOD TO ENFORCE RESTRICTIONS BASED
  // ON SCHEME, HOST OR OTHER URL ANALYSIS BEFORE ALLOWING OS EXECUTION.
  ///
  /*--cef()--*/
  virtual bool OnProtocolExecution(CefRefPtr<CefBrowser> browser,
                                   const CefString& url,
                                   bool& allowOSExecution) { return false; }

  ///
  // Called on the UI thread when a server indicates via the
  // 'Content-Disposition' header that a response represents a file to download.
  // |mimeType| is the mime type for the download, |fileName| is the suggested
  // target file name and |contentLength| is either the value of the
  // 'Content-Size' header or -1 if no size was provided. Set |handler| to the
  // CefDownloadHandler instance that will recieve the file contents. Return
  // true to download the file or false to cancel the file download.
  ///
  /*--cef()--*/
  virtual bool GetDownloadHandler(CefRefPtr<CefBrowser> browser,
                                  const CefString& mimeType,
                                  const CefString& fileName,
                                  int64 contentLength,
                                  CefRefPtr<CefDownloadHandler>& handler)
                                  { return false; }

  ///
  // Called on the IO thread when the browser needs credentials from the user.
  // |isProxy| indicates whether the host is a proxy server. |host| contains the
  // hostname and port number. Set |username| and |password| and return
  // true to handle the request. Return false to cancel the request.
  ///
  /*--cef(optional_param=realm)--*/
  virtual bool GetAuthCredentials(CefRefPtr<CefBrowser> browser,
                                  bool isProxy,
                                  const CefString& host,
                                  int port,
                                  const CefString& realm,
                                  const CefString& scheme,
                                  CefString& username,
                                  CefString& password) { return false; }

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
};

#endif  // CEF_INCLUDE_CEF_REQUEST_HANDLER_H_
