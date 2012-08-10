// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2006-2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <map>

#include "include/cef_browser.h"
#include "include/cef_scheme.h"
#include "libcef/browser/browser_context.h"
#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/context.h"
#include "libcef/browser/devtools_scheme_handler.h"
#include "libcef/browser/resource_request_job.h"
#include "libcef/browser/thread_util.h"
#include "libcef/browser/url_request_context_getter.h"
#include "libcef/common/request_impl.h"
#include "libcef/common/response_impl.h"

#include "base/bind.h"
#include "base/lazy_instance.h"
#include "base/logging.h"
#include "base/message_loop.h"
#include "base/string_util.h"
#include "base/synchronization/lock.h"
#include "googleurl/src/url_util.h"
#include "net/base/completion_callback.h"
#include "net/base/io_buffer.h"
#include "net/base/upload_data.h"
#include "net/http/http_response_headers.h"
#include "net/http/http_util.h"
#include "net/url_request/url_request.h"
#include "net/url_request/url_request_about_job.h"
#include "net/url_request/url_request_context.h"
#include "net/url_request/url_request_data_job.h"
#include "net/url_request/url_request_error_job.h"
#include "net/url_request/url_request_file_job.h"
#include "net/url_request/url_request_filter.h"
#include "net/url_request/url_request_ftp_job.h"
#include "net/url_request/url_request_http_job.h"
#include "net/url_request/url_request_job.h"
#include "net/url_request/url_request_job_factory.h"

using net::URLRequestStatus;

namespace {

bool IsStandardScheme(const std::string& scheme) {
  url_parse::Component scheme_comp(0, scheme.length());
  return url_util::IsStandard(scheme.c_str(), scheme_comp);
}

// Copied from net/url_request/url_request_job_manager.cc.
struct SchemeToFactory {
  const char* scheme;
  net::URLRequest::ProtocolFactory* factory;
};
static const SchemeToFactory kBuiltinFactories[] = {
  { "http", net::URLRequestHttpJob::Factory },
  { "https", net::URLRequestHttpJob::Factory },
  { "file", net::URLRequestFileJob::Factory },
  { "ftp", net::URLRequestFtpJob::Factory },
  { "about", net::URLRequestAboutJob::Factory },
  { "data", net::URLRequestDataJob::Factory },
};

bool IsBuiltinScheme(const std::string& scheme) {
  for (size_t i = 0; i < arraysize(kBuiltinFactories); ++i)
    if (LowerCaseEqualsASCII(scheme, kBuiltinFactories[i].scheme))
      return true;
  return false;
}

net::URLRequestJob* GetBuiltinSchemeRequestJob(net::URLRequest* request,
                                               const std::string& scheme) {
  // See if the request should be handled by a built-in protocol factory.
  for (size_t i = 0; i < arraysize(kBuiltinFactories); ++i) {
    if (scheme == kBuiltinFactories[i].scheme) {
      net::URLRequestJob* job = (kBuiltinFactories[i].factory)(request, scheme);
      DCHECK(job);  // The built-in factories are not expected to fail!
      return job;
    }
  }

  return NULL;
}

std::string ToLower(const std::string& str) {
  std::string str_lower = str;
  std::transform(str_lower.begin(), str_lower.end(), str_lower.begin(),
      towlower);
  return str;
}

// Class that manages the CefSchemeHandlerFactory instances.
class CefUrlRequestManager {
 protected:
  // Class used for creating URLRequestJob instances. The lifespan of this
  // object is managed by URLRequestJobFactory.
  class ProtocolHandler : public net::URLRequestJobFactory::ProtocolHandler {
   public:
    explicit ProtocolHandler(const std::string& scheme)
      : scheme_(scheme) {}

    // From net::URLRequestJobFactory::ProtocolHandler
    virtual net::URLRequestJob* MaybeCreateJob(
        net::URLRequest* request) const OVERRIDE {
      CEF_REQUIRE_IOT();
      return CefUrlRequestManager::GetInstance()->GetRequestJob(request,
                                                                scheme_);
    }

   private:
    std::string scheme_;
  };

 public:
  CefUrlRequestManager() {}

  // Retrieve the singleton instance.
  static CefUrlRequestManager* GetInstance();

  net::URLRequestJobFactory* GetJobFactory() {
    return const_cast<net::URLRequestJobFactory*>(
        static_cast<CefURLRequestContextGetter*>(
            _Context->browser_context()->GetRequestContext())->
                GetURLRequestContext()->job_factory());
  }

  bool AddFactory(const std::string& scheme,
                  const std::string& domain,
                  CefRefPtr<CefSchemeHandlerFactory> factory) {
    if (!factory.get()) {
      RemoveFactory(scheme, domain);
      return true;
    }

    CEF_REQUIRE_IOT();

    std::string scheme_lower = ToLower(scheme);
    std::string domain_lower = ToLower(domain);

    // Hostname is only supported for standard schemes.
    if (!IsStandardScheme(scheme_lower))
      domain_lower.clear();

    handler_map_[make_pair(scheme_lower, domain_lower)] = factory;

    net::URLRequestJobFactory* job_factory = GetJobFactory();
    job_factory->SetProtocolHandler(scheme_lower,
                                    new ProtocolHandler(scheme_lower));

    return true;
  }

  void RemoveFactory(const std::string& scheme,
                     const std::string& domain) {
    CEF_REQUIRE_IOT();

    std::string scheme_lower = ToLower(scheme);
    std::string domain_lower = ToLower(domain);

    // Hostname is only supported for standard schemes.
    if (!IsStandardScheme(scheme_lower))
      domain_lower.clear();

    HandlerMap::iterator iter =
        handler_map_.find(make_pair(scheme_lower, domain_lower));
    if (iter != handler_map_.end())
      handler_map_.erase(iter);
  }

  // Clear all the existing URL handlers and unregister the ProtocolFactory.
  void ClearFactories() {
    CEF_REQUIRE_IOT();

    net::URLRequestJobFactory* job_factory = GetJobFactory();

    // Unregister with the ProtocolFactory.
    std::set<std::string> schemes;
    for (HandlerMap::const_iterator i = handler_map_.begin();
        i != handler_map_.end(); ++i) {
      schemes.insert(i->first.first);
    }
    for (std::set<std::string>::const_iterator scheme = schemes.begin();
        scheme != schemes.end(); ++scheme) {
      job_factory->SetProtocolHandler(*scheme, NULL);
    }

    handler_map_.clear();
  }

 private:
  // Retrieve the matching handler factory, if any. |scheme| will already be in
  // lower case.
  CefRefPtr<CefSchemeHandlerFactory> GetHandlerFactory(
      net::URLRequest* request, const std::string& scheme) {
    CefRefPtr<CefSchemeHandlerFactory> factory;

    if (request->url().is_valid() && IsStandardScheme(scheme)) {
      // Check for a match with a domain first.
      const std::string& domain = request->url().host();

      HandlerMap::iterator i = handler_map_.find(make_pair(scheme, domain));
      if (i != handler_map_.end())
        factory = i->second;
    }

    if (!factory.get()) {
      // Check for a match with no specified domain.
      HandlerMap::iterator i =
          handler_map_.find(make_pair(scheme, std::string()));
      if (i != handler_map_.end())
        factory = i->second;
    }

    return factory;
  }

  // Create the job that will handle the request. |scheme| will already be in
  // lower case.
  net::URLRequestJob* GetRequestJob(net::URLRequest* request,
                                    const std::string& scheme) {
    net::URLRequestJob* job = NULL;
    CefRefPtr<CefSchemeHandlerFactory> factory =
        GetHandlerFactory(request, scheme);
    if (factory) {
      CefRefPtr<CefBrowserHostImpl> browser =
          CefBrowserHostImpl::GetBrowserForRequest(request);
      CefRefPtr<CefFrame> frame;
      if (browser.get())
        frame = browser->GetFrameForRequest(request);

      // Populate the request data.
      CefRefPtr<CefRequestImpl> requestPtr(new CefRequestImpl());
      requestPtr->Set(request);

      // Call the handler factory to create the handler for the request.
      CefRefPtr<CefResourceHandler> handler =
          factory->Create(browser.get(), frame, scheme, requestPtr.get());
      if (handler.get())
        job = new CefResourceRequestJob(request, handler);
    }

    if (!job && IsBuiltinScheme(scheme)) {
      // Give the built-in scheme handler a chance to handle the request.
      job = GetBuiltinSchemeRequestJob(request, scheme);
    }

#ifndef NDEBUG
    if (job)
      DLOG(INFO) << "CefUrlRequestManager hit for " << request->url().spec();
#endif

    return job;
  }

  // Map (scheme, domain) to factories. This map will only be accessed on the IO
  // thread.
  typedef std::map<std::pair<std::string, std::string>,
      CefRefPtr<CefSchemeHandlerFactory> > HandlerMap;
  HandlerMap handler_map_;

  DISALLOW_EVIL_CONSTRUCTORS(CefUrlRequestManager);
};

base::LazyInstance<CefUrlRequestManager> g_manager = LAZY_INSTANCE_INITIALIZER;

CefUrlRequestManager* CefUrlRequestManager::GetInstance() {
  return g_manager.Pointer();
}

}  // namespace


bool CefRegisterSchemeHandlerFactory(
    const CefString& scheme_name,
    const CefString& domain_name,
    CefRefPtr<CefSchemeHandlerFactory> factory) {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return false;
  }

  if (CEF_CURRENTLY_ON(CEF_IOT)) {
    return CefUrlRequestManager::GetInstance()->AddFactory(scheme_name,
                                                           domain_name,
                                                           factory);
  } else {
    CEF_POST_TASK(CEF_IOT,
        base::Bind(base::IgnoreResult(&CefRegisterSchemeHandlerFactory),
                   scheme_name, domain_name, factory));
    return true;
  }
}

bool CefClearSchemeHandlerFactories() {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return false;
  }

  if (CEF_CURRENTLY_ON(CEF_IOT)) {
    CefUrlRequestManager::GetInstance()->ClearFactories();

    // Re-register the DevTools scheme handler.
    RegisterDevToolsSchemeHandler();
  } else {
    CEF_POST_TASK(CEF_IOT,
        base::Bind(base::IgnoreResult(&CefClearSchemeHandlerFactories)));
  }

  return true;
}
