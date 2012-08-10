// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_BROWSER_URLREQUEST_IMPL_H_
#define CEF_LIBCEF_BROWSER_BROWSER_URLREQUEST_IMPL_H_

#include "include/cef_urlrequest.h"
#include "base/memory/ref_counted.h"

class CefBrowserURLRequest : public CefURLRequest {
 public:
  class Context;

  CefBrowserURLRequest(CefRefPtr<CefRequest> request,
                       CefRefPtr<CefURLRequestClient> client);
  virtual ~CefBrowserURLRequest();

  bool Start();

  // CefURLRequest methods.
  virtual CefRefPtr<CefRequest> GetRequest() OVERRIDE;
  virtual CefRefPtr<CefURLRequestClient> GetClient() OVERRIDE;
  virtual Status GetRequestStatus() OVERRIDE;
  virtual ErrorCode GetRequestError() OVERRIDE;
  virtual CefRefPtr<CefResponse> GetResponse() OVERRIDE;
  virtual void Cancel() OVERRIDE;

 private:
  bool VerifyContext();

  scoped_refptr<Context> context_;

  IMPLEMENT_REFCOUNTING(CefBrowserURLRequest);
};

#endif  // CEF_LIBCEF_BROWSER_BROWSER_URLREQUEST_IMPL_H_
