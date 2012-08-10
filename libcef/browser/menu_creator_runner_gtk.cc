// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/menu_creator_runner_gtk.h"
#include "libcef/browser/browser_host_impl.h"

#include "content/public/browser/render_widget_host_view.h"
#include "content/public/browser/web_contents_view.h"
#include "ui/gfx/point.h"

namespace {

class CefMenuDelegate : public MenuGtk::Delegate {
 public:
  CefMenuDelegate() {}
};

}  // namespace


CefMenuCreatorRunnerGtk::CefMenuCreatorRunnerGtk() {
}

bool CefMenuCreatorRunnerGtk::RunContextMenu(CefMenuCreator* manager) {
  if (!menu_delegate_.get())
    menu_delegate_.reset(new CefMenuDelegate);

  // Create a menu based on the model.
  menu_.reset(new MenuGtk(menu_delegate_.get(), manager->model()));

  gfx::Rect bounds;
  manager->browser()->GetWebContents()->GetView()->GetContainerBounds(&bounds);
  gfx::Point point = bounds.origin();
  point.Offset(manager->params().x, manager->params().y);

  content::RenderWidgetHostView* view =
      manager->browser()->GetWebContents()->GetRenderWidgetHostView();
  GdkEventButton* event = view->GetLastMouseDown();
  uint32_t triggering_event_time = event ? event->time : GDK_CURRENT_TIME;
 
  // Show the menu. Execution will continue asynchronously.
  menu_->PopupAsContext(point, triggering_event_time);

  return true;
}
