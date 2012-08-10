// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_URL_REQUEST_CONTEXT_PROXY_H_
#define CEF_LIBCEF_BROWSER_URL_REQUEST_CONTEXT_PROXY_H_
#pragma once

#include "base/memory/scoped_ptr.h"
#include "net/url_request/url_request_context.h"

class CefBrowserHostImpl;

namespace net {
class CookieStore;
class URLRequestContextGetter;
}

class CefURLRequestContextProxy : public net::URLRequestContext {
 public:
  explicit CefURLRequestContextProxy(net::URLRequestContextGetter* parent);
  virtual ~CefURLRequestContextProxy();

  virtual const std::string& GetUserAgent(const GURL& url) const OVERRIDE;

  void Initialize(CefBrowserHostImpl* browser);

  // We may try to delete this proxy multiple times if URLRequests are still
  // pending. Keep track of the number of tries so that they don't become
  // excessive.
  int delete_try_count() const { return delete_try_count_; }
  void increment_delete_try_count() { delete_try_count_++; }

 private:
  net::URLRequestContextGetter* parent_;
  scoped_refptr<net::CookieStore> cookie_store_proxy_;

  int delete_try_count_;

  DISALLOW_COPY_AND_ASSIGN(CefURLRequestContextProxy);
};

#endif  // CEF_LIBCEF_BROWSER_URL_REQUEST_CONTEXT_PROXY_H_
