// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/renderer/content_renderer_client.h"

#include "libcef/common/cef_messages.h"
#include "libcef/common/content_client.h"
#include "libcef/renderer/browser_impl.h"
#include "libcef/renderer/render_process_observer.h"
#include "libcef/renderer/thread_util.h"
#include "libcef/renderer/v8_impl.h"

#include "content/common/child_thread.h"
#include "content/public/renderer/render_thread.h"
#include "content/public/renderer/render_view.h"
#include "ipc/ipc_sync_channel.h"
#include "third_party/WebKit/Source/Platform/chromium/public/WebPrerenderingSupport.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebFrame.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebPrerendererClient.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebSecurityPolicy.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebString.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebView.h"
#include "v8/include/v8.h"


namespace {

// Stub implementation of WebKit::WebPrerenderingSupport.
class CefPrerenderingSupport : public WebKit::WebPrerenderingSupport {
 public:
  virtual ~CefPrerenderingSupport() {}

 private:
  virtual void add(const WebKit::WebPrerender& prerender) OVERRIDE {}
  virtual void cancel(const WebKit::WebPrerender& prerender) OVERRIDE {}
  virtual void abandon(const WebKit::WebPrerender& prerender) OVERRIDE {}
};

// Stub implementation of WebKit::WebPrerendererClient.
class CefPrerendererClient : public content::RenderViewObserver,
                             public WebKit::WebPrerendererClient {
 public:
  explicit CefPrerendererClient(content::RenderView* render_view)
      : content::RenderViewObserver(render_view) {
    DCHECK(render_view);
    render_view->GetWebView()->setPrerendererClient(this);
  }

 private:
  virtual ~CefPrerendererClient() {}

  virtual void willAddPrerender(WebKit::WebPrerender* prerender) OVERRIDE {}
};

}  // namespace

struct CefContentRendererClient::SchemeInfo {
  std::string scheme_name;
  bool is_local;
  bool is_display_isolated;
};

CefContentRendererClient::CefContentRendererClient() {
}

CefContentRendererClient::~CefContentRendererClient() {
}

// static
CefContentRendererClient* CefContentRendererClient::Get() {
  return static_cast<CefContentRendererClient*>(
      content::GetContentClient()->renderer());
}

CefRefPtr<CefBrowserImpl> CefContentRendererClient::GetBrowserForView(
    content::RenderView* view) {
  CEF_REQUIRE_RT_RETURN(NULL);

  BrowserMap::const_iterator it = browsers_.find(view);
  if (it != browsers_.end())
    return it->second;
  return NULL;
}

CefRefPtr<CefBrowserImpl> CefContentRendererClient::GetBrowserForMainFrame(
    WebKit::WebFrame* frame) {
  CEF_REQUIRE_RT_RETURN(NULL);

  BrowserMap::const_iterator it = browsers_.begin();
  for (; it != browsers_.end(); ++it) {
    content::RenderView* render_view = it->second->render_view();
    if (render_view && render_view->GetWebView() &&
        render_view->GetWebView()->mainFrame() == frame) {
      return it->second;
    }
  }

  return NULL;
}

void CefContentRendererClient::OnBrowserDestroyed(CefBrowserImpl* browser) {
  BrowserMap::iterator it = browsers_.begin();
  for (; it != browsers_.end(); ++it) {
    if (it->second.get() == browser) {
      browsers_.erase(it);
      return;
    }
  }

  // No browser was found in the map.
  NOTREACHED();
}

void CefContentRendererClient::AddCustomScheme(
    const std::string& scheme_name,
    bool is_local,
    bool is_display_isolated) {
  SchemeInfo info = {scheme_name, is_local, is_display_isolated};
  scheme_info_list_.push_back(info);
}

void CefContentRendererClient::RegisterCustomSchemes() {
  if (scheme_info_list_.empty())
    return;

  SchemeInfoList::const_iterator it = scheme_info_list_.begin();
  for (; it != scheme_info_list_.end(); ++it) {
    const SchemeInfo& info = *it;
    if (info.is_local) {
      WebKit::WebSecurityPolicy::registerURLSchemeAsLocal(
          WebKit::WebString::fromUTF8(info.scheme_name));
    }
    if (info.is_display_isolated) {
      WebKit::WebSecurityPolicy::registerURLSchemeAsDisplayIsolated(
          WebKit::WebString::fromUTF8(info.scheme_name));
    }
  }
}

void CefContentRendererClient::RenderThreadStarted() {
  render_loop_ = base::MessageLoopProxy::current();
  observer_.reset(new CefRenderProcessObserver());

  content::RenderThread* thread = content::RenderThread::Get();
  thread->AddObserver(observer_.get());

  WebKit::WebPrerenderingSupport::initialize(new CefPrerenderingSupport());

  thread->Send(new CefProcessHostMsg_RenderThreadStarted);

  // Notify the render process handler.
  CefRefPtr<CefApp> application = CefContentClient::Get()->application();
  if (application.get()) {
    CefRefPtr<CefRenderProcessHandler> handler =
        application->GetRenderProcessHandler();
    if (handler.get())
      handler->OnRenderThreadCreated();
  }
}

void CefContentRendererClient::RenderViewCreated(
    content::RenderView* render_view) {
  CefRefPtr<CefBrowserImpl> browser = new CefBrowserImpl(render_view);
  browsers_.insert(std::make_pair(render_view, browser));

  new CefPrerendererClient(render_view);
}

void CefContentRendererClient::DidCreateScriptContext(
    WebKit::WebFrame* frame, v8::Handle<v8::Context> context,
    int extension_group, int world_id) {
  // Notify the render process handler.
  CefRefPtr<CefApp> application = CefContentClient::Get()->application();
  if (!application.get())
    return;

  CefRefPtr<CefRenderProcessHandler> handler =
      application->GetRenderProcessHandler();
  if (!handler.get())
    return;

  CefRefPtr<CefBrowserImpl> browserPtr =
      CefBrowserImpl::GetBrowserForMainFrame(frame->top());
  DCHECK(browserPtr.get());
  if (!browserPtr.get())
    return;

  CefRefPtr<CefFrameImpl> framePtr = browserPtr->GetWebFrameImpl(frame);

  v8::HandleScope handle_scope;
  v8::Context::Scope scope(context);

  CefRefPtr<CefV8Context> contextPtr(new CefV8ContextImpl(context));

  handler->OnContextCreated(browserPtr.get(), framePtr.get(), contextPtr);
}

void CefContentRendererClient::WillReleaseScriptContext(
    WebKit::WebFrame* frame, v8::Handle<v8::Context> context, int world_id) {
  // Notify the render process handler.
  CefRefPtr<CefApp> application = CefContentClient::Get()->application();
  if (!application.get())
    return;

  CefRefPtr<CefRenderProcessHandler> handler =
      application->GetRenderProcessHandler();
  if (!handler.get())
    return;

  CefRefPtr<CefBrowserImpl> browserPtr =
      CefBrowserImpl::GetBrowserForMainFrame(frame->top());
  DCHECK(browserPtr.get());
  if (!browserPtr.get())
    return;

  CefRefPtr<CefFrameImpl> framePtr = browserPtr->GetWebFrameImpl(frame);

  v8::HandleScope handle_scope;
  v8::Context::Scope scope(context);

  CefRefPtr<CefV8Context> contextPtr(new CefV8ContextImpl(context));

  handler->OnContextReleased(browserPtr.get(), framePtr.get(), contextPtr);
}
