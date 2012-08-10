// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_BROWSER_MESSAGE_LOOP_H_
#define CEF_LIBCEF_BROWSER_BROWSER_MESSAGE_LOOP_H_
#pragma once

#include "base/basictypes.h"
#include "base/message_loop.h"

// Class used to process events on the current message loop.
class CefBrowserMessageLoop : public MessageLoopForUI {
  typedef MessageLoopForUI inherited;

 public:
  CefBrowserMessageLoop();
  virtual ~CefBrowserMessageLoop();

  // Returns the MessageLoopForUI of the current thread.
  static CefBrowserMessageLoop* current();

  virtual bool DoIdleWork();

  // Do a single interation of the UI message loop.
  void DoMessageLoopIteration();

  // Run the UI message loop.
  void RunMessageLoop();

  bool is_iterating() { return is_iterating_; }

 private:
  // True if the message loop is doing one iteration at a time.
  bool is_iterating_;

  DISALLOW_COPY_AND_ASSIGN(CefBrowserMessageLoop);
};

#endif  // CEF_LIBCEF_BROWSER_BROWSER_MESSAGE_LOOP_H_
