// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/resource_context.h"
#include "libcef/browser/thread_util.h"
#include "libcef/browser/url_request_context_getter.h"

CefResourceContext::CefResourceContext(
    CefURLRequestContextGetter* getter)
    : getter_(getter) {
}

CefResourceContext::~CefResourceContext() {
  // Destroy the getter after content::ResourceContext has finished destructing.
  // Otherwise, the URLRequestContext objects will be deleted before
  // ResourceDispatcherHost has canceled any pending URLRequests.
  content::BrowserThread::ReleaseSoon(
      content::BrowserThread::IO, FROM_HERE, getter_.release());
}

net::HostResolver* CefResourceContext::GetHostResolver() {
  CEF_REQUIRE_IOT();
  return getter_->host_resolver();
}

net::URLRequestContext* CefResourceContext::GetRequestContext() {
  CEF_REQUIRE_IOT();
  return getter_->GetURLRequestContext();
}
