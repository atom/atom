// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/resource_dispatcher_host_delegate.h"
#include "libcef/browser/browser_host_impl.h"

CefResourceDispatcherHostDelegate::CefResourceDispatcherHostDelegate() {
}

CefResourceDispatcherHostDelegate::~CefResourceDispatcherHostDelegate() {
}

void CefResourceDispatcherHostDelegate::HandleExternalProtocol(const GURL& url,
                                                               int child_id,
                                                               int route_id) {
  CefRefPtr<CefBrowserHostImpl> browser =
      CefBrowserHostImpl::GetBrowserByRoutingID(child_id, route_id);
  if (browser.get())
    browser->HandleExternalProtocol(url);
}
