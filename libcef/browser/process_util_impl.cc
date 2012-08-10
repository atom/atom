// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_process_util.h"
#include "libcef/common/command_line_impl.h"

#include "base/logging.h"
#include "base/process_util.h"
#include "content/public/browser/browser_thread.h"

bool CefLaunchProcess(CefRefPtr<CefCommandLine> command_line) {
  if (!command_line.get()) {
    NOTREACHED() << "invalid parameter";
    return false;
  }

  if (!content::BrowserThread::CurrentlyOn(
          content::BrowserThread::PROCESS_LAUNCHER)) {
    NOTREACHED() << "called on invalid thread";
    return false;
  }

  CefCommandLineImpl* impl =
      static_cast<CefCommandLineImpl*>(command_line.get());

  CefValueController::AutoLock lock_scope(impl->controller());

  base::LaunchOptions options;
  return base::LaunchProcess(impl->command_line(), options, NULL);
}
