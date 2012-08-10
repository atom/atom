// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/url_request_context_getter.h"

#if defined(OS_WIN)
#include <winhttp.h>
#endif
#include <string>
#include <vector>

#include "libcef/browser/context.h"
#include "libcef/browser/thread_util.h"
#include "libcef/browser/url_network_delegate.h"
#include "libcef/browser/url_request_context_proxy.h"
#include "libcef/browser/url_request_interceptor.h"

#include "base/file_util.h"
#include "base/logging.h"
#include "base/stl_util.h"
#include "base/string_split.h"
#include "base/threading/thread_restrictions.h"
#include "base/threading/worker_pool.h"
#include "chrome/browser/net/sqlite_persistent_cookie_store.h"
#include "content/public/browser/browser_thread.h"
#include "net/base/cert_verifier.h"
#include "net/base/default_server_bound_cert_store.h"
#include "net/base/host_resolver.h"
#include "net/base/server_bound_cert_service.h"
#include "net/base/ssl_config_service_defaults.h"
#include "net/cookies/cookie_monster.h"
#include "net/ftp/ftp_network_layer.h"
#include "net/http/http_auth_handler_factory.h"
#include "net/http/http_cache.h"
#include "net/http/http_server_properties_impl.h"
#include "net/proxy/proxy_config_service.h"
#include "net/proxy/proxy_config_service_fixed.h"
#include "net/proxy/proxy_resolver.h"
#include "net/proxy/proxy_service.h"
#include "net/url_request/url_request.h"
#include "net/url_request/url_request_context.h"
#include "net/url_request/url_request_context_storage.h"
#include "net/url_request/url_request_job_factory.h"
#include "net/url_request/url_request_job_manager.h"

using content::BrowserThread;

#if defined(OS_WIN)
#pragma comment(lib, "winhttp.lib")
#endif

namespace {

#if defined(OS_WIN)

// ProxyConfigService implementation that does nothing.
class ProxyConfigServiceNull : public net::ProxyConfigService {
 public:
  ProxyConfigServiceNull() {}
  virtual void AddObserver(Observer* observer) OVERRIDE {}
  virtual void RemoveObserver(Observer* observer) OVERRIDE {}
  virtual ProxyConfigService::ConfigAvailability
      GetLatestProxyConfig(net::ProxyConfig* config) OVERRIDE {
    return ProxyConfigService::CONFIG_VALID;
  }
  virtual void OnLazyPoll() OVERRIDE {}

  DISALLOW_COPY_AND_ASSIGN(ProxyConfigServiceNull);
};

#endif  // defined(OS_WIN)

// ProxyResolver implementation that forewards resolution to a CefProxyHandler.
class CefProxyResolver : public net::ProxyResolver {
 public:
  explicit CefProxyResolver(CefRefPtr<CefProxyHandler> handler)
    : ProxyResolver(false),
      handler_(handler) {}
  virtual ~CefProxyResolver() {}

  virtual int GetProxyForURL(const GURL& url,
                             net::ProxyInfo* results,
                             const net::CompletionCallback& callback,
                             RequestHandle* request,
                             const net::BoundNetLog& net_log) OVERRIDE {
    CefProxyInfo proxy_info;
    handler_->GetProxyForUrl(url.spec(), proxy_info);
    if (proxy_info.IsDirect())
      results->UseDirect();
    else if (proxy_info.IsNamedProxy())
      results->UseNamedProxy(proxy_info.ProxyList());
    else if (proxy_info.IsPacString())
      results->UsePacString(proxy_info.ProxyList());

    return net::OK;
  }

  virtual int SetPacScript(
      const scoped_refptr<net::ProxyResolverScriptData>& pac_script,
      const net::CompletionCallback& callback) OVERRIDE {
    return net::OK;
  }

  virtual void CancelRequest(RequestHandle request) OVERRIDE {}
  virtual net::LoadState GetLoadState(RequestHandle request) const OVERRIDE {
    return net::LOAD_STATE_IDLE;
  }
  virtual net::LoadState GetLoadStateThreadSafe(RequestHandle request) const
      OVERRIDE {
    return net::LOAD_STATE_IDLE;
  }
  virtual void CancelSetPacScript() OVERRIDE {}

 protected:
  CefRefPtr<CefProxyHandler> handler_;

  DISALLOW_COPY_AND_ASSIGN(CefProxyResolver);
};

}  // namespace

CefURLRequestContextGetter::CefURLRequestContextGetter(
    const FilePath& base_path,
    MessageLoop* io_loop,
    MessageLoop* file_loop)
    : base_path_(base_path),
      io_loop_(io_loop),
      file_loop_(file_loop) {
  // Must first be created on the UI thread.
  CEF_REQUIRE_UIT();

#if !defined(OS_WIN)
  // We must create the proxy config service on the UI loop on Linux because it
  // must synchronously run on the glib message loop. This will be passed to
  // the URLRequestContextStorage on the IO thread in GetURLRequestContext().
  CreateProxyConfigService();
#endif
}

CefURLRequestContextGetter::~CefURLRequestContextGetter() {
  STLDeleteElements(&url_request_context_proxies_);
}

net::URLRequestContext* CefURLRequestContextGetter::GetURLRequestContext() {
  CEF_REQUIRE_IOT();

  if (!url_request_context_.get()) {
    const FilePath& cache_path = _Context->cache_path();

    url_request_context_.reset(new net::URLRequestContext());
    storage_.reset(
        new net::URLRequestContextStorage(url_request_context_.get()));

    SetCookieStoragePath(cache_path);

    storage_->set_network_delegate(new CefNetworkDelegate);

    storage_->set_server_bound_cert_service(new net::ServerBoundCertService(
        new net::DefaultServerBoundCertStore(NULL),
        base::WorkerPool::GetTaskRunner(true)));
    url_request_context_->set_accept_language("en-us,en");
    url_request_context_->set_accept_charset("iso-8859-1,*,utf-8");

    storage_->set_host_resolver(
        net::CreateSystemHostResolver(net::HostResolver::kDefaultParallelism,
                                      net::HostResolver::kDefaultRetryAttempts,
                                      NULL));
    storage_->set_cert_verifier(net::CertVerifier::CreateDefault());

    bool proxy_service_set = false;

    CefRefPtr<CefApp> app = _Context->application();
    if (app.get()) {
      CefRefPtr<CefBrowserProcessHandler> handler =
          app->GetBrowserProcessHandler();
      if (handler.get()) {
        CefRefPtr<CefProxyHandler> proxy_handler = handler->GetProxyHandler();
        if (proxy_handler.get()) {
          // The client will provide proxy resolution.
          CreateProxyConfigService();
          storage_->set_proxy_service(
              new net::ProxyService(proxy_config_service_.release(),
                                    new CefProxyResolver(proxy_handler), NULL));
          proxy_service_set = true;
        }
      }
    }

    // TODO(jam): use v8 if possible, look at chrome code.
#if defined(OS_WIN)
    if (!proxy_service_set) {
      const CefSettings& settings = _Context->settings();
      if (!settings.auto_detect_proxy_settings_enabled) {
        // Using the system proxy resolver on Windows when "Automatically detect
        // settings" (auto-detection) is checked under LAN Settings can hurt
        // resource loading performance because the call to
        // WinHttpGetProxyForUrl in proxy_resolver_winhttp.cc will block the
        // IO thread.  This is especially true for Windows 7 where auto-
        // detection is checked by default. To avoid slow resource loading on
        // Windows we only use the system proxy resolver if auto-detection is
        // unchecked.
        WINHTTP_CURRENT_USER_IE_PROXY_CONFIG ie_config = {0};
        if (WinHttpGetIEProxyConfigForCurrentUser(&ie_config)) {
          if (ie_config.fAutoDetect == TRUE) {
            storage_->set_proxy_service(
                net::ProxyService::CreateWithoutProxyResolver(
                    new ProxyConfigServiceNull(), NULL));
            proxy_service_set = true;
          }

          if (ie_config.lpszAutoConfigUrl)
            GlobalFree(ie_config.lpszAutoConfigUrl);
          if (ie_config.lpszProxy)
            GlobalFree(ie_config.lpszProxy);
          if (ie_config.lpszProxyBypass)
            GlobalFree(ie_config.lpszProxyBypass);
        }
      }
    }
#endif  // defined(OS_WIN)

    if (!proxy_service_set) {
      CreateProxyConfigService();
      storage_->set_proxy_service(
          net::ProxyService::CreateUsingSystemProxyResolver(
              proxy_config_service_.release(), 0, NULL));
    }

    storage_->set_ssl_config_service(new net::SSLConfigServiceDefaults);

    // Add support for single sign-on.
    url_security_manager_.reset(net::URLSecurityManager::Create(NULL, NULL));

    std::vector<std::string> supported_schemes;
    supported_schemes.push_back("basic");
    supported_schemes.push_back("digest");
    supported_schemes.push_back("ntlm");
    supported_schemes.push_back("negotiate");

    storage_->set_http_auth_handler_factory(
        net::HttpAuthHandlerRegistryFactory::Create(
            supported_schemes,
            url_security_manager_.get(),
            url_request_context_->host_resolver(),
            std::string(),
            false,
            false));
    storage_->set_http_server_properties(new net::HttpServerPropertiesImpl);

    net::HttpCache::DefaultBackend* main_backend =
        new net::HttpCache::DefaultBackend(
            cache_path.empty() ? net::MEMORY_CACHE : net::DISK_CACHE,
            cache_path,
            0,
            BrowserThread::GetMessageLoopProxyForThread(
                BrowserThread::CACHE));

    net::HttpCache* main_cache = new net::HttpCache(
        url_request_context_->host_resolver(),
        url_request_context_->cert_verifier(),
        url_request_context_->server_bound_cert_service(),
        NULL,  /* tranport_security_state */
        url_request_context_->proxy_service(),
        "",  /* ssl_session_cache_shard */
        url_request_context_->ssl_config_service(),
        url_request_context_->http_auth_handler_factory(),
        NULL,  /* network_delegate */
        url_request_context_->http_server_properties(),
        NULL,
        main_backend,
        ""  /* trusted_spdy_proxy */);
    storage_->set_http_transaction_factory(main_cache);

    storage_->set_ftp_transaction_factory(
      new net::FtpNetworkLayer(url_request_context_->host_resolver()));

    storage_->set_job_factory(new net::URLRequestJobFactory);

    request_interceptor_.reset(new CefRequestInterceptor);
  }

  return url_request_context_.get();
}

scoped_refptr<base::SingleThreadTaskRunner>
    CefURLRequestContextGetter::GetNetworkTaskRunner() const {
  return BrowserThread::GetMessageLoopProxyForThread(CEF_IOT);
}

net::HostResolver* CefURLRequestContextGetter::host_resolver() {
  return url_request_context_->host_resolver();
}

void CefURLRequestContextGetter::SetCookieStoragePath(const FilePath& path) {
  CEF_REQUIRE_IOT();

  if (url_request_context_->cookie_store() &&
      ((cookie_store_path_.empty() && path.empty()) ||
       cookie_store_path_ == path)) {
    // The path has not changed so don't do anything.
    return;
  }

  scoped_refptr<SQLitePersistentCookieStore> persistent_store;
  if (!path.empty()) {
    // TODO(cef): Move directory creation to the blocking pool instead of
    // allowing file IO on this thread.
    base::ThreadRestrictions::ScopedAllowIO allow_io;
    if (file_util::DirectoryExists(path) ||
        file_util::CreateDirectory(path)) {
      const FilePath& cookie_path = path.AppendASCII("Cookies");
      persistent_store =
          new SQLitePersistentCookieStore(cookie_path, false, NULL);
    } else {
      NOTREACHED() << "The cookie storage directory could not be created";
    }
  }

  // Set the new cookie store that will be used for all new requests. The old
  // cookie store, if any, will be automatically flushed and closed when no
  // longer referenced.
  storage_->set_cookie_store(
      new net::CookieMonster(persistent_store.get(), NULL));
  cookie_store_path_ = path;

  // Restore the previously supported schemes.
  SetCookieSupportedSchemes(cookie_supported_schemes_);
}

void CefURLRequestContextGetter::SetCookieSupportedSchemes(
    const std::vector<std::string>& schemes) {
  CEF_REQUIRE_IOT();

  cookie_supported_schemes_ = schemes;

  if (cookie_supported_schemes_.empty()) {
    cookie_supported_schemes_.push_back("http");
    cookie_supported_schemes_.push_back("https");
  }

  std::set<std::string> scheme_set;
  std::vector<std::string>::const_iterator it =
      cookie_supported_schemes_.begin();
  for (; it != cookie_supported_schemes_.end(); ++it)
    scheme_set.insert(*it);

  const char** arr = new const char*[scheme_set.size()];
  std::set<std::string>::const_iterator it2 = scheme_set.begin();
  for (int i = 0; it2 != scheme_set.end(); ++it2, ++i)
    arr[i] = it2->c_str();

  url_request_context_->cookie_store()->GetCookieMonster()->
      SetCookieableSchemes(arr, scheme_set.size());

  delete [] arr;
}

CefURLRequestContextProxy*
    CefURLRequestContextGetter::CreateURLRequestContextProxy() {
  CEF_REQUIRE_IOT();
  CefURLRequestContextProxy* proxy = new CefURLRequestContextProxy(this);
  url_request_context_proxies_.insert(proxy);
  return proxy;
}

void CefURLRequestContextGetter::ReleaseURLRequestContextProxy(
    CefURLRequestContextProxy* proxy) {
  CEF_REQUIRE_IOT();

  // Don't do anything if we're currently shutting down. The proxy objects will
  // be deleted when this object is destroyed.
  if (_Context->shutting_down())
    return;

  if (proxy->url_requests()->size() == 0) {
    // Safe to delete the proxy.
    RequestContextProxySet::iterator it =
        url_request_context_proxies_.find(proxy);
    DCHECK(it != url_request_context_proxies_.end());
    url_request_context_proxies_.erase(it);
    delete proxy;
  } else {
    proxy->increment_delete_try_count();
    if (proxy->delete_try_count() <= 1) {
      // Cancel the pending requests. This may result in additional tasks being
      // posted on the IO thread.
      std::set<const net::URLRequest*>::iterator it =
          proxy->url_requests()->begin();
      for (; it != proxy->url_requests()->end(); ++it)
        const_cast<net::URLRequest*>(*it)->Cancel();

      // Try to delete the proxy again later.
      CEF_POST_TASK(CEF_IOT,
          base::Bind(&CefURLRequestContextGetter::ReleaseURLRequestContextProxy,
                     this, proxy));
    } else {
      NOTREACHED() <<
          "too many retries to delete URLRequestContext proxy object";
    }
  }
}

void CefURLRequestContextGetter::CreateProxyConfigService() {
  if (proxy_config_service_.get())
    return;

  proxy_config_service_.reset(
      net::ProxyService::CreateSystemProxyConfigService(
          io_loop_->message_loop_proxy(), file_loop_));
}
