// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_GTK_H_
#define CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_GTK_H_
#pragma once

#include "libcef/browser/menu_creator.h"

#include "base/memory/scoped_ptr.h"
#include "chrome/browser/ui/gtk/menu_gtk.h"

class CefMenuCreatorRunnerGtk: public CefMenuCreator::Runner {
 public:
  CefMenuCreatorRunnerGtk();

  // CefMemoryManager::Runner methods.
  virtual bool RunContextMenu(CefMenuCreator* manager) OVERRIDE;

 private:
  scoped_ptr<MenuGtk> menu_;
  scoped_ptr<MenuGtk::Delegate> menu_delegate_;
};

#endif  // CEF_LIBCEF_BROWSER_MENU_MANAGER_RUNNER_GTK_H_
