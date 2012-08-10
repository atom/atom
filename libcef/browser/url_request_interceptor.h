// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_URL_REQUEST_INTERCEPTOR_H_
#define CEF_LIBCEF_BROWSER_URL_REQUEST_INTERCEPTOR_H_
#pragma once

#include "net/url_request/url_request.h"

// Used for intercepting resource requests, redirects and responses. The single
// instance of this class is managed by CefURLRequestContextGetter.
class CefRequestInterceptor : public net::URLRequest::Interceptor {
 public:
  CefRequestInterceptor();
  ~CefRequestInterceptor();

  // net::URLRequest::Interceptor methods.
  virtual net::URLRequestJob* MaybeIntercept(net::URLRequest* request)
      OVERRIDE;
  virtual net::URLRequestJob* MaybeInterceptRedirect(net::URLRequest* request,
      const GURL& location) OVERRIDE;
  virtual net::URLRequestJob* MaybeInterceptResponse(net::URLRequest* request)
      OVERRIDE;

  DISALLOW_COPY_AND_ASSIGN(CefRequestInterceptor);
};

#endif  // CEF_LIBCEF_BROWSER_URL_REQUEST_INTERCEPTOR_H_
