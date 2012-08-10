// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <gtk/gtk.h>

#include "ui/base/events.h"

// This file includes a selection of methods copied from
// chrome/browser/ui/gtk/gtk_util.cc.

namespace gtk_util {

void SetAlwaysShowImage(GtkWidget* image_menu_item) {
  gtk_image_menu_item_set_always_show_image(
      GTK_IMAGE_MENU_ITEM(image_menu_item), TRUE);
}

}  // namespace gtk_util


namespace event_utils {

int EventFlagsFromGdkState(guint state) {
  int flags = 0;
  flags |= (state & GDK_LOCK_MASK) ? ui::EF_CAPS_LOCK_DOWN : 0;
  flags |= (state & GDK_CONTROL_MASK) ? ui::EF_CONTROL_DOWN : 0;
  flags |= (state & GDK_SHIFT_MASK) ? ui::EF_SHIFT_DOWN : 0;
  flags |= (state & GDK_MOD1_MASK) ? ui::EF_ALT_DOWN : 0;
  flags |= (state & GDK_BUTTON1_MASK) ? ui::EF_LEFT_MOUSE_BUTTON : 0;
  flags |= (state & GDK_BUTTON2_MASK) ? ui::EF_MIDDLE_MOUSE_BUTTON : 0;
  flags |= (state & GDK_BUTTON3_MASK) ? ui::EF_RIGHT_MOUSE_BUTTON : 0;
  return flags;
}

}  // namespace event_utils
