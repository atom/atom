// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/browser_main.h"

#include <string>

#include "libcef/browser/browser_context.h"
#include "libcef/browser/browser_message_loop.h"
#include "libcef/browser/content_browser_client.h"
#include "libcef/browser/devtools_delegate.h"

#include "base/bind.h"
#include "base/command_line.h"
#include "base/message_loop.h"
#include "base/string_number_conversions.h"
#include "base/threading/thread.h"
#include "base/threading/thread_restrictions.h"
#include "content/browser/browser_process_sub_thread.h"
#include "content/browser/download/download_file_manager.h"
#include "content/browser/download/save_file_manager.h"
#include "content/browser/plugin_service_impl.h"
#include "content/public/browser/gpu_data_manager.h"
#include "content/public/common/content_client.h"
#include "content/public/common/content_switches.h"
#include "net/base/net_module.h"
#include "ui/base/resource/resource_bundle.h"

namespace {

base::StringPiece ResourceProvider(int resource_id) {
  return content::GetContentClient()->GetDataResource(resource_id,
                                                      ui::SCALE_FACTOR_NONE);
}

}  // namespace

CefBrowserMainParts::CefBrowserMainParts(
    const content::MainFunctionParams& parameters)
    : BrowserMainParts(),
      devtools_delegate_(NULL) {
}

CefBrowserMainParts::~CefBrowserMainParts() {
}

void CefBrowserMainParts::PreMainMessageLoopStart() {
  if (!MessageLoop::current()) {
    // Create the browser message loop.
    message_loop_.reset(new CefBrowserMessageLoop());
    message_loop_->set_thread_name("CrBrowserMain");
  }
}

int CefBrowserMainParts::PreCreateThreads() {
  PlatformInitialize();
  net::NetModule::SetResourceProvider(&ResourceProvider);

  // Initialize the GpuDataManager before IO access restrictions are applied and
  // before the IO thread is started.
  content::GpuDataManager::GetInstance();

  return 0;
}

void CefBrowserMainParts::PreMainMessageLoopRun() {
  browser_context_.reset(new CefBrowserContext());

  const CommandLine& command_line = *CommandLine::ForCurrentProcess();
  if (command_line.HasSwitch(switches::kRemoteDebuggingPort)) {
    std::string port_str =
        command_line.GetSwitchValueASCII(switches::kRemoteDebuggingPort);
    int port;
    if (base::StringToInt(port_str, &port) && port > 0 && port < 65535) {
      devtools_delegate_ = new CefDevToolsDelegate(
          port,
          browser_context_->GetRequestContext());
    } else {
      DLOG(WARNING) << "Invalid http debugger port number " << port;
    }
  }
}

void CefBrowserMainParts::PostMainMessageLoopRun() {
  if (devtools_delegate_)
    devtools_delegate_->Stop();
  browser_context_.reset();
}

void CefBrowserMainParts::PostDestroyThreads() {
  PlatformCleanup();
}
