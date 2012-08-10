// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_RESPONSE_IMPL_H_
#define CEF_LIBCEF_COMMON_RESPONSE_IMPL_H_
#pragma once

#include "include/cef_response.h"

namespace net {
class HttpResponseHeaders;
}

namespace WebKit {
class WebURLResponse;
}

// Implementation of CefResponse.
class CefResponseImpl : public CefResponse {
 public:
  CefResponseImpl();
  ~CefResponseImpl() {}

  // CefResponse methods.
  virtual bool IsReadOnly() OVERRIDE;
  virtual int GetStatus() OVERRIDE;
  virtual void SetStatus(int status) OVERRIDE;
  virtual CefString GetStatusText() OVERRIDE;
  virtual void SetStatusText(const CefString& statusText) OVERRIDE;
  virtual CefString GetMimeType() OVERRIDE;
  virtual void SetMimeType(const CefString& mimeType) OVERRIDE;
  virtual CefString GetHeader(const CefString& name) OVERRIDE;
  virtual void GetHeaderMap(HeaderMap& headerMap) OVERRIDE;
  virtual void SetHeaderMap(const HeaderMap& headerMap) OVERRIDE;

  net::HttpResponseHeaders* GetResponseHeaders();
  void SetResponseHeaders(const net::HttpResponseHeaders& headers);

  void Set(const WebKit::WebURLResponse& response);

  void SetReadOnly(bool read_only);

 protected:
  int status_code_;
  CefString status_text_;
  CefString mime_type_;
  HeaderMap header_map_;
  bool read_only_;

  IMPLEMENT_REFCOUNTING(CefResponseImpl);
  IMPLEMENT_LOCKING(CefResponseImpl);
};

#endif  // CEF_LIBCEF_COMMON_RESPONSE_IMPL_H_
