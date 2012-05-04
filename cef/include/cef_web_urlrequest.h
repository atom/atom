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

#ifndef CEF_INCLUDE_CEF_WEB_URLREQUEST_H_
#define CEF_INCLUDE_CEF_WEB_URLREQUEST_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_request.h"
#include "include/cef_response.h"

class CefWebURLRequestClient;

///
// Class used to make a Web URL request. Web URL requests are not associated
// with a browser instance so no CefClient callbacks will be executed. The
// methods of this class may be called on any thread.
///
/*--cef(source=library)--*/
class CefWebURLRequest : public virtual CefBase {
 public:
  typedef cef_weburlrequest_state_t RequestState;

  ///
  // Create a new CefWebUrlRequest object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefWebURLRequest> CreateWebURLRequest(
      CefRefPtr<CefRequest> request,
      CefRefPtr<CefWebURLRequestClient> client);

  ///
  // Cancels the request.
  ///
  /*--cef()--*/
  virtual void Cancel() =0;

  ///
  // Returns the current ready state of the request.
  ///
  /*--cef(default_retval=WUR_STATE_UNSENT)--*/
  virtual RequestState GetState() =0;
};

///
// Interface that should be implemented by the CefWebURLRequest client. The
// methods of this class will always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefWebURLRequestClient : public virtual CefBase {
 public:
  typedef cef_weburlrequest_state_t RequestState;
  typedef cef_handler_errorcode_t ErrorCode;

  ///
  // Notifies the client that the request state has changed. State change
  // notifications will always be sent before the below notification methods
  // are called.
  ///
  /*--cef()--*/
  virtual void OnStateChange(CefRefPtr<CefWebURLRequest> requester,
                             RequestState state) =0;

  ///
  // Notifies the client that the request has been redirected and  provides a
  // chance to change the request parameters.
  ///
  /*--cef()--*/
  virtual void OnRedirect(CefRefPtr<CefWebURLRequest> requester,
                          CefRefPtr<CefRequest> request,
                          CefRefPtr<CefResponse> response) =0;

  ///
  // Notifies the client of the response data.
  ///
  /*--cef()--*/
  virtual void OnHeadersReceived(CefRefPtr<CefWebURLRequest> requester,
                                 CefRefPtr<CefResponse> response) =0;

  ///
  // Notifies the client of the upload progress.
  ///
  /*--cef()--*/
  virtual void OnProgress(CefRefPtr<CefWebURLRequest> requester,
                          uint64 bytesSent, uint64 totalBytesToBeSent) =0;

  ///
  // Notifies the client that content has been received.
  ///
  /*--cef()--*/
  virtual void OnData(CefRefPtr<CefWebURLRequest> requester,
                      const void* data, int dataLength) =0;

  ///
  // Notifies the client that the request ended with an error.
  ///
  /*--cef()--*/
  virtual void OnError(CefRefPtr<CefWebURLRequest> requester,
                       ErrorCode errorCode) =0;
};

#endif  // CEF_INCLUDE_CEF_WEB_URLREQUEST_H_
