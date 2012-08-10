// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/url_request_interceptor.h"

#include <string>

#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/resource_request_job.h"
#include "libcef/browser/thread_util.h"
#include "libcef/common/request_impl.h"

#include "net/url_request/url_request_job_manager.h"
#include "net/url_request/url_request_redirect_job.h"

CefRequestInterceptor::CefRequestInterceptor() {
  CEF_REQUIRE_IOT();
  net::URLRequestJobManager::GetInstance()->RegisterRequestInterceptor(this);
}

CefRequestInterceptor::~CefRequestInterceptor() {
  CEF_REQUIRE_IOT();
  net::URLRequestJobManager::GetInstance()->
      UnregisterRequestInterceptor(this);
}

net::URLRequestJob* CefRequestInterceptor::MaybeIntercept(
    net::URLRequest* request) {
  CefRefPtr<CefBrowserHostImpl> browser =
      CefBrowserHostImpl::GetBrowserForRequest(request);
  if (browser.get()) {
    CefRefPtr<CefClient> client = browser->GetClient();
    if (client.get()) {
      CefRefPtr<CefRequestHandler> handler = client->GetRequestHandler();
      if (handler.get()) {
        CefRefPtr<CefFrame> frame = browser->GetFrameForRequest(request);

        // Populate the request data.
        CefRefPtr<CefRequest> req(CefRequest::Create());
        static_cast<CefRequestImpl*>(req.get())->Set(request);

        // Give the client an opportunity to replace the request.
        CefRefPtr<CefResourceHandler> resourceHandler =
            handler->GetResourceHandler(browser.get(), frame, req);
        if (resourceHandler.get())
          return new CefResourceRequestJob(request, resourceHandler);
      }
    }
  }

  return NULL;
}

net::URLRequestJob* CefRequestInterceptor::MaybeInterceptRedirect(
    net::URLRequest* request, const GURL& location) {
  CefRefPtr<CefBrowserHostImpl> browser =
      CefBrowserHostImpl::GetBrowserForRequest(request);
  if (browser.get()) {
    CefRefPtr<CefClient> client = browser->GetClient();
    if (client.get()) {
      CefRefPtr<CefRequestHandler> handler = client->GetRequestHandler();
      if (handler.get()) {
        CefRefPtr<CefFrame> frame = browser->GetFrameForRequest(request);

        // Give the client an opportunity to redirect the request.
        CefString newUrlStr = location.spec();
        handler->OnResourceRedirect(browser.get(), frame, request->url().spec(),
            newUrlStr);
        if (newUrlStr != location.spec()) {
          GURL new_url = GURL(std::string(newUrlStr));
          if (!new_url.is_empty() && new_url.is_valid())
            return new net::URLRequestRedirectJob(request, new_url);
        }
      }
    }
  }

  return NULL;
}

net::URLRequestJob* CefRequestInterceptor::MaybeInterceptResponse(
    net::URLRequest* request) {
  return NULL;
}
