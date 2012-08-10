// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/url_network_delegate.h"

#include <string>

#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/thread_util.h"
#include "libcef/common/request_impl.h"

#include "net/base/net_errors.h"
#include "net/url_request/url_request.h"

namespace {

class CefAuthCallbackImpl : public CefAuthCallback {
 public:
  CefAuthCallbackImpl(const net::NetworkDelegate::AuthCallback& callback,
                      net::AuthCredentials* credentials)
      : callback_(callback),
        credentials_(credentials) {
  }
  ~CefAuthCallbackImpl() {
    if (!callback_.is_null()) {
      // The auth callback is still pending. Cancel it now.
      if (CEF_CURRENTLY_ON_IOT()) {
        CancelNow(callback_);
      } else {
        CEF_POST_TASK(CEF_IOT,
            base::Bind(&CefAuthCallbackImpl::CancelNow, callback_));
      }
    }
  }

  virtual void Continue(const CefString& username,
                        const CefString& password) OVERRIDE {
    if (CEF_CURRENTLY_ON_IOT()) {
      if (!callback_.is_null()) {
        credentials_->Set(username, password);
        callback_.Run(net::NetworkDelegate::AUTH_REQUIRED_RESPONSE_SET_AUTH);
        callback_.Reset();
      }
    } else {
      CEF_POST_TASK(CEF_IOT,
          base::Bind(&CefAuthCallbackImpl::Continue, this, username, password));
    }
  }

  virtual void Cancel() OVERRIDE {
    if (CEF_CURRENTLY_ON_IOT()) {
      if (!callback_.is_null()) {
        CancelNow(callback_);
        callback_.Reset();
      }
    } else {
      CEF_POST_TASK(CEF_IOT, base::Bind(&CefAuthCallbackImpl::Cancel, this));
    }
  }

  void Disconnect() {
    callback_.Reset();
  }

 private:
  static void CancelNow(const net::NetworkDelegate::AuthCallback& callback) {
    CEF_REQUIRE_IOT();
    callback.Run(net::NetworkDelegate::AUTH_REQUIRED_RESPONSE_NO_ACTION);
  }

  net::NetworkDelegate::AuthCallback callback_;
  net::AuthCredentials* credentials_;

  IMPLEMENT_REFCOUNTING(CefAuthCallbackImpl);
};

}  // namespace

CefNetworkDelegate::CefNetworkDelegate() {
}

CefNetworkDelegate::~CefNetworkDelegate() {
}

int CefNetworkDelegate::OnBeforeURLRequest(
    net::URLRequest* request,
    const net::CompletionCallback& callback,
    GURL* new_url) {
  CefRefPtr<CefBrowserHostImpl> browser =
      CefBrowserHostImpl::GetBrowserForRequest(request);
  if (browser.get()) {
    CefRefPtr<CefClient> client = browser->GetClient();
    if (client.get()) {
      CefRefPtr<CefRequestHandler> handler = client->GetRequestHandler();
      if (handler.get()) {
        CefRefPtr<CefFrame> frame = browser->GetFrameForRequest(request);

        GURL old_url = request->url();

        // Populate the request data.
        CefRefPtr<CefRequestImpl> requestPtr(new CefRequestImpl());
        requestPtr->Set(request);

        // Give the client an opportunity to cancel the request.
        if (handler->OnBeforeResourceLoad(browser.get(), frame,
            requestPtr.get())) {
          return net::ERR_ABORTED;
        }

        GURL url = GURL(std::string(requestPtr->GetURL()));
        if (old_url != url)
          new_url ->Swap(&url);

        requestPtr->Get(request);
      }
    }
  }

  return net::OK;
}

int CefNetworkDelegate::OnBeforeSendHeaders(
    net::URLRequest* request,
    const net::CompletionCallback& callback,
    net::HttpRequestHeaders* headers) {
  return net::OK;
}

void CefNetworkDelegate::OnSendHeaders(
    net::URLRequest* request,
    const net::HttpRequestHeaders& headers) {
}

int CefNetworkDelegate::OnHeadersReceived(
    net::URLRequest* request,
    const net::CompletionCallback& callback,
    net::HttpResponseHeaders* original_response_headers,
    scoped_refptr<net::HttpResponseHeaders>* override_response_headers) {
  return net::OK;
}

void CefNetworkDelegate::OnBeforeRedirect(net::URLRequest* request,
                                          const GURL& new_location) {
}

void CefNetworkDelegate::OnResponseStarted(net::URLRequest* request) {
}

void CefNetworkDelegate::OnRawBytesRead(const net::URLRequest& request,
                                        int bytes_read) {
}

void CefNetworkDelegate::OnCompleted(net::URLRequest* request, bool started) {
}

void CefNetworkDelegate::OnURLRequestDestroyed(net::URLRequest* request) {
}

void CefNetworkDelegate::OnPACScriptError(int line_number,
                                          const string16& error) {
}

net::NetworkDelegate::AuthRequiredResponse CefNetworkDelegate::OnAuthRequired(
    net::URLRequest* request,
    const net::AuthChallengeInfo& auth_info,
    const AuthCallback& callback,
    net::AuthCredentials* credentials) {
  CefRefPtr<CefBrowserHostImpl> browser =
      CefBrowserHostImpl::GetBrowserForRequest(request);
  if (browser.get()) {
    CefRefPtr<CefClient> client = browser->GetClient();
    if (client.get()) {
      CefRefPtr<CefRequestHandler> handler = client->GetRequestHandler();
      if (handler.get()) {
        CefRefPtr<CefFrame> frame = browser->GetFrameForRequest(request);

        CefRefPtr<CefAuthCallbackImpl> callbackPtr(
            new CefAuthCallbackImpl(callback, credentials));
        if (handler->GetAuthCredentials(browser.get(),
                                        frame,
                                        auth_info.is_proxy,
                                        auth_info.challenger.host(),
                                        auth_info.challenger.port(),
                                        auth_info.realm,
                                        auth_info.scheme,
                                        callbackPtr.get())) {
          return AUTH_REQUIRED_RESPONSE_IO_PENDING;
        } else {
          callbackPtr->Disconnect();
        }
      }
    }
  }

  return AUTH_REQUIRED_RESPONSE_NO_ACTION;
}

bool CefNetworkDelegate::OnCanGetCookies(const net::URLRequest& request,
                                         const net::CookieList& cookie_list) {
  return true;
}

bool CefNetworkDelegate::OnCanSetCookie(const net::URLRequest& request,
                                        const std::string& cookie_line,
                                        net::CookieOptions* options) {
  return true;
}

bool CefNetworkDelegate::OnCanAccessFile(const net::URLRequest& request,
                                         const FilePath& path) const {
  return true;
}

bool CefNetworkDelegate::OnCanThrottleRequest(
    const net::URLRequest& request) const {
  return false;
}

int CefNetworkDelegate::OnBeforeSocketStreamConnect(
    net::SocketStream* socket,
    const net::CompletionCallback& callback) {
  return net::OK;
}
