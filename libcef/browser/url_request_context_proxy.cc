// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/url_request_context_proxy.h"

#include <string>

#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/cookie_manager_impl.h"
#include "libcef/browser/thread_util.h"

#include "base/logging.h"
#include "base/message_loop_proxy.h"
#include "net/cookies/cookie_store.h"
#include "net/url_request/url_request_context_getter.h"

namespace {

class CefCookieStoreProxy : public net::CookieStore {
 public:
  explicit CefCookieStoreProxy(CefBrowserHostImpl* browser,
                               net::URLRequestContext* parent)
      : parent_(parent),
        browser_(browser) {
  }

  // net::CookieStore methods.
  virtual void SetCookieWithOptionsAsync(
      const GURL& url,
      const std::string& cookie_line,
      const net::CookieOptions& options,
      const SetCookiesCallback& callback) OVERRIDE {
    scoped_refptr<net::CookieStore> cookie_store = GetCookieStore();
    cookie_store->SetCookieWithOptionsAsync(url, cookie_line, options,
                                            callback);
  }

  virtual void GetCookiesWithOptionsAsync(
      const GURL& url, const net::CookieOptions& options,
      const GetCookiesCallback& callback) OVERRIDE {
    scoped_refptr<net::CookieStore> cookie_store = GetCookieStore();
    cookie_store->GetCookiesWithOptionsAsync(url, options, callback);
  }

  void GetCookiesWithInfoAsync(
      const GURL& url,
      const net::CookieOptions& options,
      const GetCookieInfoCallback& callback) OVERRIDE {
    scoped_refptr<net::CookieStore> cookie_store = GetCookieStore();
    cookie_store->GetCookiesWithInfoAsync(url, options, callback);
  }

  virtual void DeleteCookieAsync(const GURL& url,
                                 const std::string& cookie_name,
                                 const base::Closure& callback) OVERRIDE {
    scoped_refptr<net::CookieStore> cookie_store = GetCookieStore();
    cookie_store->DeleteCookieAsync(url, cookie_name, callback);
  }

  virtual void DeleteAllCreatedBetweenAsync(const base::Time& delete_begin,
                                            const base::Time& delete_end,
                                            const DeleteCallback& callback)
                                            OVERRIDE {
    scoped_refptr<net::CookieStore> cookie_store = GetCookieStore();
    cookie_store->DeleteAllCreatedBetweenAsync(delete_begin, delete_end,
                                               callback);
  }

  virtual void DeleteSessionCookiesAsync(const DeleteCallback& callback)
                                         OVERRIDE {
    scoped_refptr<net::CookieStore> cookie_store = GetCookieStore();
    cookie_store->DeleteSessionCookiesAsync(callback);
  }

  virtual net::CookieMonster* GetCookieMonster() OVERRIDE {
    scoped_refptr<net::CookieStore> cookie_store = GetCookieStore();
    return cookie_store->GetCookieMonster();
  }

 private:
  net::CookieStore* GetCookieStore() {
    CEF_REQUIRE_IOT();

    scoped_refptr<net::CookieStore> cookie_store;

    CefRefPtr<CefClient> client = browser_->GetClient();
    if (client.get()) {
      CefRefPtr<CefRequestHandler> handler = client->GetRequestHandler();
      if (handler.get()) {
        // Get the manager from the handler.
        CefRefPtr<CefCookieManager> manager =
            handler->GetCookieManager(browser_,
                                      browser_->GetLoadingURL().spec());
        if (manager.get()) {
          cookie_store =
            reinterpret_cast<CefCookieManagerImpl*>(
                manager.get())->cookie_monster();
          DCHECK(cookie_store);
        }
      }
    }

    if (!cookie_store) {
      // Use the global cookie store.
      cookie_store = parent_->cookie_store();
    }

    DCHECK(cookie_store);
    return cookie_store;
  }

  // This pointer is guaranteed by the CefRequestContextProxy object.
  net::URLRequestContext* parent_;
  CefBrowserHostImpl* browser_;

  DISALLOW_COPY_AND_ASSIGN(CefCookieStoreProxy);
};

}  // namespace


CefURLRequestContextProxy::CefURLRequestContextProxy(
    net::URLRequestContextGetter* parent)
    : parent_(parent),
      delete_try_count_(0) {
}

CefURLRequestContextProxy::~CefURLRequestContextProxy() {
}

const std::string& CefURLRequestContextProxy::GetUserAgent(const GURL& url) const {
  return parent_->GetURLRequestContext()->GetUserAgent(url);
}

void CefURLRequestContextProxy::Initialize(CefBrowserHostImpl* browser) {
  CEF_REQUIRE_IOT();

  net::URLRequestContext* context = parent_->GetURLRequestContext();

  // Cookie store that proxies to the browser implementation.
  cookie_store_proxy_ = new CefCookieStoreProxy(browser, context);
  set_cookie_store(cookie_store_proxy_);

  // All other values refer to the parent request context.
  set_net_log(context->net_log());
  set_host_resolver(context->host_resolver());
  set_cert_verifier(context->cert_verifier());
  set_server_bound_cert_service(context->server_bound_cert_service());
  set_fraudulent_certificate_reporter(
      context->fraudulent_certificate_reporter());
  set_proxy_service(context->proxy_service());
  set_ssl_config_service(context->ssl_config_service());
  set_http_auth_handler_factory(context->http_auth_handler_factory());
  set_http_transaction_factory(context->http_transaction_factory());
  set_ftp_transaction_factory(context->ftp_transaction_factory());
  set_network_delegate(context->network_delegate());
  set_http_server_properties(context->http_server_properties());
  set_transport_security_state(context->transport_security_state());
  set_accept_charset(context->accept_charset());
  set_accept_language(context->accept_language());
  set_referrer_charset(context->referrer_charset());
  set_job_factory(context->job_factory());
}
