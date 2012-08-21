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
// The contents of this file are only available to applications that link
// against the libcef_dll_wrapper target.
//

#ifndef CEF_INCLUDE_WRAPPER_CEF_STREAM_RESOURCE_HANDLER_H_
#define CEF_INCLUDE_WRAPPER_CEF_STREAM_RESOURCE_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_resource_handler.h"
#include "include/cef_response.h"

class CefStreamReader;

///
// Implementation of the CefResourceHandler class for reading from a CefStream.
///
class CefStreamResourceHandler : public CefResourceHandler {
 public:
  ///
  // Create a new object with default response values.
  ///
  CefStreamResourceHandler(const CefString& mime_type,
                           CefRefPtr<CefStreamReader> stream);
  ///
  // Create a new object with explicit response values.
  ///
  CefStreamResourceHandler(int status_code,
                           const CefString& mime_type,
                           CefResponse::HeaderMap header_map,
                           CefRefPtr<CefStreamReader> stream);

  // CefStreamResourceHandler methods.
  virtual bool ProcessRequest(CefRefPtr<CefRequest> request,
                              CefRefPtr<CefCallback> callback) OVERRIDE;
  virtual void GetResponseHeaders(CefRefPtr<CefResponse> response,
                                  int64& response_length,
                                  CefString& redirectUrl) OVERRIDE;
  virtual bool ReadResponse(void* data_out,
                            int bytes_to_read,
                            int& bytes_read,
                            CefRefPtr<CefCallback> callback) OVERRIDE;
  virtual void Cancel() OVERRIDE;

 private:
  int status_code_;
  CefString mime_type_;
  CefResponse::HeaderMap header_map_;
  CefRefPtr<CefStreamReader> stream_;

  IMPLEMENT_REFCOUNTING(CefStreamResourceHandler);
};

#endif  // CEF_INCLUDE_WRAPPER_CEF_STREAM_RESOURCE_HANDLER_H_
