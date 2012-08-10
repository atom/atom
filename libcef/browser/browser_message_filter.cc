/// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/browser_message_filter.h"

#include "libcef/browser/origin_whitelist_impl.h"
#include "libcef/browser/thread_util.h"
#include "libcef/common/cef_messages.h"

#include "base/compiler_specific.h"
#include "base/bind.h"

CefBrowserMessageFilter::CefBrowserMessageFilter(
    content::RenderProcessHost* host)
    : host_(host),
      channel_(NULL) {
}

CefBrowserMessageFilter::~CefBrowserMessageFilter() {
}

void CefBrowserMessageFilter::OnFilterAdded(IPC::Channel* channel) {
  channel_ = channel;
}

void CefBrowserMessageFilter::OnFilterRemoved() {
}

bool CefBrowserMessageFilter::OnMessageReceived(const IPC::Message& message) {
  bool handled = true;
  IPC_BEGIN_MESSAGE_MAP(CefBrowserMessageFilter, message)
    IPC_MESSAGE_HANDLER(CefProcessHostMsg_RenderThreadStarted,
                        OnRenderThreadStarted)
    IPC_MESSAGE_UNHANDLED(handled = false)
  IPC_END_MESSAGE_MAP()
  return handled;
}

void CefBrowserMessageFilter::OnRenderThreadStarted() {
  // Execute registration on the UI thread.
  CEF_POST_TASK(CEF_UIT,
      base::Bind(&CefBrowserMessageFilter::RegisterOnUIThread, this));
}

void CefBrowserMessageFilter::RegisterOnUIThread() {
  CEF_REQUIRE_UIT();
  
  // Send existing registrations to the new render process.
  RegisterCrossOriginWhitelistEntriesWithHost(host_);
}
