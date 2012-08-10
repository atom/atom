// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_MAC_H_
#define CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_MAC_H_
#pragma once

#include "libcef/browser/menu_creator.h"

#if __OBJC__
@class MenuController;
#else
class MenuController;
#endif

class CefMenuCreatorRunnerMac : public CefMenuCreator::Runner {
 public:
  CefMenuCreatorRunnerMac();
  virtual ~CefMenuCreatorRunnerMac();

  // CefMemoryManager::Runner methods.
  virtual bool RunContextMenu(CefMenuCreator* manager) OVERRIDE;

 private:
  MenuController* menu_controller_;
};

#endif  // CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_MAC_H_
