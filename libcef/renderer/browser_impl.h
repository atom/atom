// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_RENDERER_BROWSER_IMPL_H_
#define CEF_LIBCEF_RENDERER_BROWSER_IMPL_H_
#pragma once

#include <map>
#include <string>
#include <vector>

#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "libcef/common/tracker.h"
#include "libcef/renderer/frame_impl.h"

#include "base/memory/scoped_ptr.h"
#include "content/public/renderer/render_view_observer.h"

class GURL;
struct CefMsg_LoadRequest_Params;
struct Cef_Request_Params;
struct Cef_Response_Params;
class CefContentRendererClient;
class CefResponseManager;

namespace base {
class ListValue;
}

namespace WebKit {
class WebFrame;
}

// Renderer plumbing for CEF features. There is a one-to-one relationship
// between RenderView on the renderer side and RenderViewHost on the browser
// side.
//
// RenderViewObserver: Interface for observing RenderView notifications and IPC
// messages. IPC messages received by the RenderView will be forwarded to this
// RenderViewObserver implementation. IPC messages sent using
// RenderViewObserver::Send() will be forwarded to the RenderView. Use
// RenderViewObserver::routing_id() when sending IPC messages.
class CefBrowserImpl : public CefBrowser,
                       public content::RenderViewObserver {
 public:
  // Returns the browser associated with the specified RenderView.
  static CefRefPtr<CefBrowserImpl> GetBrowserForView(content::RenderView* view);
  // Returns the browser associated with the specified main WebFrame.
  static CefRefPtr<CefBrowserImpl> GetBrowserForMainFrame(
      WebKit::WebFrame* frame);

  // CefBrowser methods.
  virtual CefRefPtr<CefBrowserHost> GetHost() OVERRIDE;
  virtual bool CanGoBack() OVERRIDE;
  virtual void GoBack() OVERRIDE;
  virtual bool CanGoForward() OVERRIDE;
  virtual void GoForward() OVERRIDE;
  virtual bool IsLoading() OVERRIDE;
  virtual void Reload() OVERRIDE;
  virtual void ReloadIgnoreCache() OVERRIDE;
  virtual void StopLoad() OVERRIDE;
  virtual int GetIdentifier() OVERRIDE;
  virtual bool IsPopup() OVERRIDE;
  virtual bool HasDocument() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetMainFrame() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetFocusedFrame() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetFrame(int64 identifier) OVERRIDE;
  virtual CefRefPtr<CefFrame> GetFrame(const CefString& name) OVERRIDE;
  virtual size_t GetFrameCount() OVERRIDE;
  virtual void GetFrameIdentifiers(std::vector<int64>& identifiers) OVERRIDE;
  virtual void GetFrameNames(std::vector<CefString>& names) OVERRIDE;
  virtual bool SendProcessMessage(
      CefProcessId target_process,
      CefRefPtr<CefProcessMessage> message) OVERRIDE;

  explicit CefBrowserImpl(content::RenderView* render_view);
  virtual ~CefBrowserImpl();

  void LoadRequest(const CefMsg_LoadRequest_Params& params);

  // Returns the matching CefFrameImpl reference or creates a new one.
  CefRefPtr<CefFrameImpl> GetWebFrameImpl(WebKit::WebFrame* frame);
  CefRefPtr<CefFrameImpl> GetWebFrameImpl(int64 frame_id);

  // Frame objects will be deleted immediately before the frame is closed.
  void AddFrameObject(int64 frame_id, CefTrackNode* tracked_object);

  int browser_window_id() const { return browser_window_id_; }
  content::RenderView* render_view() {
    return content::RenderViewObserver::render_view();
  }

 private:
  // RenderViewObserver methods.
  virtual void OnDestruct() OVERRIDE;
  virtual void DidStartProvisionalLoad(WebKit::WebFrame* frame) OVERRIDE;
  virtual void FrameDetached(WebKit::WebFrame* frame) OVERRIDE;
  virtual void FocusedNodeChanged(const WebKit::WebNode& node) OVERRIDE;
  virtual void DidCreateDataSource(WebKit::WebFrame* frame,
                                   WebKit::WebDataSource* ds) OVERRIDE;
  virtual bool OnMessageReceived(const IPC::Message& message) OVERRIDE;

  // RenderViewObserver::OnMessageReceived message handlers.
  void OnUpdateBrowserWindowId(int window_id, bool is_popup);
  void OnRequest(const Cef_Request_Params& params);
  void OnResponse(const Cef_Response_Params& params);
  void OnResponseAck(int request_id);

  // Id number of browser window which RenderView is attached to.
  int browser_window_id_;
  bool is_popup_;

  // Id of the last frame that had focus.
  int64 last_focused_frame_id_;

  // Map of unique frame ids to CefFrameImpl references.
  typedef std::map<int64, CefRefPtr<CefFrameImpl> > FrameMap;
  FrameMap frames_;

  // Map of unique frame ids to CefTrackManager objects that need to be cleaned
  // up when the frame is deleted.
  typedef std::map<int64, CefRefPtr<CefTrackManager> > FrameObjectMap;
  FrameObjectMap frame_objects_;

  // Manages response registrations.
  scoped_ptr<CefResponseManager> response_manager_;

  IMPLEMENT_REFCOUNTING(CefBrowserImpl);
  DISALLOW_COPY_AND_ASSIGN(CefBrowserImpl);
};

#endif  // CEF_LIBCEF_RENDERER_BROWSER_IMPL_H_
