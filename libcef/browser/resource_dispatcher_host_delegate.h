// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_RESOURCE_DISPATCHER_HOST_DELEGATE_H_
#define CEF_LIBCEF_BROWSER_RESOURCE_DISPATCHER_HOST_DELEGATE_H_
#pragma once

#include "content/public/browser/resource_dispatcher_host_delegate.h"

// Implements ResourceDispatcherHostDelegate.
class CefResourceDispatcherHostDelegate
    : public content::ResourceDispatcherHostDelegate {
 public:
  CefResourceDispatcherHostDelegate();
  virtual ~CefResourceDispatcherHostDelegate();

  // ResourceDispatcherHostDelegate methods.
  virtual void HandleExternalProtocol(const GURL& url,
                                      int child_id,
                                      int route_id) OVERRIDE;

 private:
  DISALLOW_COPY_AND_ASSIGN(CefResourceDispatcherHostDelegate);
};

#endif  // CEF_LIBCEF_BROWSER_RESOURCE_DISPATCHER_HOST_DELEGATE_H_
