// Copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_BROWSER_MAIN_H_
#define CEF_LIBCEF_BROWSER_BROWSER_MAIN_H_
#pragma once

#include "base/basictypes.h"
#include "base/memory/scoped_ptr.h"
#include "base/string_piece.h"
#include "content/public/browser/browser_main_parts.h"

namespace base {
class Thread;
}

namespace content {
struct MainFunctionParams;
}

class CefBrowserContext;
class CefDevToolsDelegate;
class MessageLoop;

class CefBrowserMainParts : public content::BrowserMainParts {
 public:
  explicit CefBrowserMainParts(const content::MainFunctionParams& parameters);
  virtual ~CefBrowserMainParts();

  virtual void PreMainMessageLoopStart() OVERRIDE;
  virtual int PreCreateThreads() OVERRIDE;
  virtual void PreMainMessageLoopRun() OVERRIDE;
  virtual void PostMainMessageLoopRun() OVERRIDE;
  virtual void PostDestroyThreads() OVERRIDE;

  CefBrowserContext* browser_context() const { return browser_context_.get(); }
  CefDevToolsDelegate* devtools_delegate() const { return devtools_delegate_; }

 private:
  void PlatformInitialize();
  void PlatformCleanup();

  scoped_ptr<CefBrowserContext> browser_context_;

  scoped_ptr<MessageLoop> message_loop_;
  CefDevToolsDelegate* devtools_delegate_;

  DISALLOW_COPY_AND_ASSIGN(CefBrowserMainParts);
};

#endif  // CEF_LIBCEF_BROWSER_BROWSER_MAIN_H_
