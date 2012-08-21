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

#ifndef CEF_INCLUDE_CEF_RESOURCE_HANDLER_H_
#define CEF_INCLUDE_CEF_RESOURCE_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_callback.h"
#include "include/cef_cookie.h"
#include "include/cef_request.h"
#include "include/cef_response.h"

///
// Class used to implement a custom request handler interface. The methods of
// this class will always be called on the IO thread.
///
/*--cef(source=client)--*/
class CefResourceHandler : public virtual CefBase {
 public:
  ///
  // Begin processing the request. To handle the request return true and call
  // CefCallback::Continue() once the response header information is available
  // (CefCallback::Continue() can also be called from inside this method if
  // header information is available immediately). To cancel the request return
  // false.
  ///
  /*--cef()--*/
  virtual bool ProcessRequest(CefRefPtr<CefRequest> request,
                              CefRefPtr<CefCallback> callback) =0;

  ///
  // Retrieve response header information. If the response length is not known
  // set |response_length| to -1 and ReadResponse() will be called until it
  // returns false. If the response length is known set |response_length|
  // to a positive value and ReadResponse() will be called until it returns
  // false or the specified number of bytes have been read. Use the |response|
  // object to set the mime type, http status code and other optional header
  // values. To redirect the request to a new URL set |redirectUrl| to the new
  // URL.
  ///
  /*--cef()--*/
  virtual void GetResponseHeaders(CefRefPtr<CefResponse> response,
                                  int64& response_length,
                                  CefString& redirectUrl) =0;

  ///
  // Read response data. If data is available immediately copy up to
  // |bytes_to_read| bytes into |data_out|, set |bytes_read| to the number of
  // bytes copied, and return true. To read the data at a later time set
  // |bytes_read| to 0, return true and call CefCallback::Continue() when the
  // data is available. To indicate response completion return false.
  ///
  /*--cef()--*/
  virtual bool ReadResponse(void* data_out,
                            int bytes_to_read,
                            int& bytes_read,
                            CefRefPtr<CefCallback> callback) =0;

  ///
  // Return true if the specified cookie can be sent with the request or false
  // otherwise. If false is returned for any cookie then no cookies will be sent
  // with the request.
  ///
  /*--cef()--*/
  virtual bool CanGetCookie(const CefCookie& cookie) { return true; }

  ///
  // Return true if the specified cookie returned with the response can be set
  // or false otherwise.
  ///
  /*--cef()--*/
  virtual bool CanSetCookie(const CefCookie& cookie) { return true; }

  ///
  // Request processing has been canceled.
  ///
  /*--cef()--*/
  virtual void Cancel() =0;
};

#endif  // CEF_INCLUDE_CEF_RESOURCE_HANDLER_H_
