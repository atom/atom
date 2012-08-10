// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/devtools_delegate.h"
#include "libcef/browser/devtools_scheme_handler.h"

#include <algorithm>
#include <string>

#include "base/command_line.h"
#include "base/md5.h"
#include "base/rand_util.h"
#include "base/stringprintf.h"
#include "base/string_number_conversions.h"
#include "base/time.h"
#include "content/public/browser/devtools_http_handler.h"
#include "content/public/browser/render_process_host.h"
#include "content/public/browser/render_view_host.h"
#include "content/public/common/content_client.h"
#include "content/public/common/content_switches.h"
#include "grit/cef_resources.h"
#include "net/base/tcp_listen_socket.h"
#include "net/url_request/url_request_context_getter.h"
#include "ui/base/layout.h"
#include "ui/base/resource/resource_bundle.h"

namespace {

class CefDevToolsBindingHandler
    : public content::DevToolsHttpHandler::RenderViewHostBinding {
 public:
  CefDevToolsBindingHandler() {
  }

  virtual std::string GetIdentifier(content::RenderViewHost* rvh) OVERRIDE {
    int process_id = rvh->GetProcess()->GetID();
    int routing_id = rvh->GetRoutingID();

    if (random_seed_.empty()) {
      // Generate a random seed that is used to make identifier guessing more
      // difficult.
      random_seed_ = base::StringPrintf("%lf|%u",
          base::Time::Now().ToDoubleT(), base::RandInt(0, INT_MAX));
    }

    // Create a key that combines RVH IDs and the random seed.
    std::string key = base::StringPrintf("%d|%d|%s",
        process_id,
        routing_id,
        random_seed_.c_str());

    // Return an MD5 hash of the key.
    return base::MD5String(key);
  }

  virtual content::RenderViewHost* ForIdentifier(
      const std::string& identifier) OVERRIDE {
    // Iterate through the existing RVH instances to find a match.
    for (content::RenderProcessHost::iterator it(
        content::RenderProcessHost::AllHostsIterator());
       !it.IsAtEnd(); it.Advance()) {
      content::RenderProcessHost* render_process_host = it.GetCurrentValue();
      DCHECK(render_process_host);

      // Ignore processes that don't have a connection, such as crashed
      // contents.
      if (!render_process_host->HasConnection())
        continue;

      content::RenderProcessHost::RenderWidgetHostsIterator rwit(
          render_process_host->GetRenderWidgetHostsIterator());
      for (; !rwit.IsAtEnd(); rwit.Advance()) {
        const content::RenderWidgetHost* widget = rwit.GetCurrentValue();
        DCHECK(widget);
        if (!widget || !widget->IsRenderView())
          continue;

        content::RenderViewHost* host =
            content::RenderViewHost::From(
                const_cast<content::RenderWidgetHost*>(widget));
        if (GetIdentifier(host) == identifier)
          return host;
      }
    }

    return NULL;
  }

 private:
  std::string random_seed_;
};

}  // namespace

CefDevToolsDelegate::CefDevToolsDelegate(
    int port,
    net::URLRequestContextGetter* context_getter) {
  devtools_http_handler_ = content::DevToolsHttpHandler::Start(
      new net::TCPListenSocketFactory("127.0.0.1", port),
      "",
      context_getter,
      this);

  binding_.reset(new CefDevToolsBindingHandler());
  devtools_http_handler_->SetRenderViewHostBinding(binding_.get());
}

CefDevToolsDelegate::~CefDevToolsDelegate() {
}

void CefDevToolsDelegate::Stop() {
  // The call below destroys this.
  devtools_http_handler_->Stop();
}

std::string CefDevToolsDelegate::GetDiscoveryPageHTML() {
  return content::GetContentClient()->GetDataResource(
      IDR_CEF_DEVTOOLS_DISCOVERY_PAGE, ui::SCALE_FACTOR_NONE).as_string();
}

bool CefDevToolsDelegate::BundlesFrontendResources() {
  return false;
}

std::string CefDevToolsDelegate::GetFrontendResourcesBaseURL() {
  return kChromeDevToolsURL;
}

std::string CefDevToolsDelegate::GetDevToolsURL(content::RenderViewHost* rvh,
                                                bool http_scheme) {
  const CommandLine& command_line = *CommandLine::ForCurrentProcess();
  std::string port_str =
      command_line.GetSwitchValueASCII(switches::kRemoteDebuggingPort);
  DCHECK(!port_str.empty());
  int port;
  if (!base::StringToInt(port_str, &port))
    return std::string();

  std::string page_id = binding_->GetIdentifier(rvh);
  std::string host = http_scheme ?
      base::StringPrintf("http://localhost:%d/devtools/", port) :
      kChromeDevToolsURL;
  
  return base::StringPrintf(
      "%sdevtools.html?ws=localhost:%d/devtools/page/%s",
      host.c_str(),
      port,
      page_id.c_str());
}
