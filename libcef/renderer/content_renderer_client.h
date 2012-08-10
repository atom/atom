// Copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_RENDERER_CONTENT_RENDERER_CLIENT_H_
#define CEF_LIBCEF_RENDERER_CONTENT_RENDERER_CLIENT_H_
#pragma once

#include <list>
#include <map>
#include <string>

#include "libcef/renderer/browser_impl.h"

#include "base/compiler_specific.h"
#include "base/memory/scoped_ptr.h"
#include "base/message_loop_proxy.h"
#include "content/public/renderer/content_renderer_client.h"

class CefRenderProcessObserver;


class CefContentRendererClient : public content::ContentRendererClient {
 public:
  CefContentRendererClient();
  virtual ~CefContentRendererClient();

  // Returns the singleton CefContentRendererClient instance.
  static CefContentRendererClient* Get();

  // Returns the browser associated with the specified RenderView.
  CefRefPtr<CefBrowserImpl> GetBrowserForView(content::RenderView* view);

  // Returns the browser associated with the specified main WebFrame.
  CefRefPtr<CefBrowserImpl> GetBrowserForMainFrame(WebKit::WebFrame* frame);

  // Called from CefBrowserImpl::OnDestruct().
  void OnBrowserDestroyed(CefBrowserImpl* browser);

  // Add a custom scheme registration.
  void AddCustomScheme(const std::string& scheme_name,
                       bool is_local,
                       bool is_display_isolated);

  // Register the custom schemes with WebKit.
  void RegisterCustomSchemes();

  // Render thread message loop proxy.
  base::MessageLoopProxy* render_loop() const { return render_loop_.get(); }

 private:
  // ContentRendererClient implementation.
  virtual void RenderThreadStarted() OVERRIDE;
  virtual void RenderViewCreated(content::RenderView* render_view) OVERRIDE;
  virtual void DidCreateScriptContext(WebKit::WebFrame* frame,
                                      v8::Handle<v8::Context> context,
                                      int extension_group,
                                      int world_id) OVERRIDE;
  virtual void WillReleaseScriptContext(WebKit::WebFrame* frame,
                                        v8::Handle<v8::Context> context,
                                        int world_id) OVERRIDE;

  scoped_refptr<base::MessageLoopProxy> render_loop_;
  scoped_ptr<CefRenderProcessObserver> observer_;

  // Map of RenderView pointers to CefBrowserImpl references.
  typedef std::map<content::RenderView*, CefRefPtr<CefBrowserImpl> > BrowserMap;
  BrowserMap browsers_;

  // Information about custom schemes that need to be registered with WebKit.
  struct SchemeInfo;
  typedef std::list<SchemeInfo> SchemeInfoList;
  SchemeInfoList scheme_info_list_;
};

#endif  // CEF_LIBCEF_RENDERER_CONTENT_RENDERER_CLIENT_H_
