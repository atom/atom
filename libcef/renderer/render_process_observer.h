// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_RENDERER_RENDER_PROCESS_OBSERVER_H_
#define CEF_LIBCEF_RENDERER_RENDER_PROCESS_OBSERVER_H_

#include <string>
#include "base/memory/ref_counted.h"
#include "content/public/renderer/render_process_observer.h"

// This class sends and receives control messages on the renderer process.
class CefRenderProcessObserver : public content::RenderProcessObserver {
 public:
  CefRenderProcessObserver();
  virtual ~CefRenderProcessObserver();

  // RenderProcessObserver implementation.
  virtual bool OnControlMessageReceived(const IPC::Message& message) OVERRIDE;
  virtual void WebKitInitialized() OVERRIDE;

 private:
  // Message handlers called on the render thread.
  void OnModifyCrossOriginWhitelistEntry(bool add,
                                         const std::string& source_origin,
                                         const std::string& target_protocol,
                                         const std::string& target_domain,
                                         bool allow_target_subdomains);
  void OnClearCrossOriginWhitelist();

  DISALLOW_COPY_AND_ASSIGN(CefRenderProcessObserver);
};


#endif  // CEF_LIBCEF_RENDERER_RENDER_PROCESS_OBSERVER_H_
