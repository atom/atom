// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_WIN_H_
#define CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_WIN_H_
#pragma once

#include "libcef/browser/menu_creator.h"

#include "base/memory/scoped_ptr.h"
#include "ui/views/controls/menu/native_menu_win.h"

class CefMenuCreatorRunnerWin : public CefMenuCreator::Runner {
 public:
  CefMenuCreatorRunnerWin();

  // CefMemoryManager::Runner methods.
  virtual bool RunContextMenu(CefMenuCreator* manager) OVERRIDE;

 private:
  scoped_ptr<views::NativeMenuWin> menu_;
};

#endif  // CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_WIN_H_
