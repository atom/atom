// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <gtk/gtk.h>
#include <stdlib.h>
#include <unistd.h>
#include <string>
#include "cefclient.h"
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_runnable.h"
#include "client_handler.h"

char szWorkingDir[512];  // The current working directory

// The global ClientHandler reference.
extern CefRefPtr<ClientHandler> g_handler;

void destroy(void) {
  CefQuitMessageLoop();
}

void TerminationSignalHandler(int signatl) {
  destroy();
}

// Callback for when you press enter in the URL box.
void URLEntryActivate(GtkEntry* entry) {
  if (!g_handler.get() || !g_handler->GetBrowserHwnd())
    return;

  const gchar* url = gtk_entry_get_text(entry);
  g_handler->GetBrowser()->GetMainFrame()->LoadURL(std::string(url).c_str());
}

// GTK utility functions ----------------------------------------------

GtkWidget* AddMenuEntry(GtkWidget* menu_widget, const char* text,
                        GCallback callback) {
  GtkWidget* entry = gtk_menu_item_new_with_label(text);
  g_signal_connect(entry, "activate", callback, NULL);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu_widget), entry);
  return entry;
}

GtkWidget* CreateMenu(GtkWidget* menu_bar, const char* text) {
  GtkWidget* menu_widget = gtk_menu_new();
  GtkWidget* menu_header = gtk_menu_item_new_with_label(text);
  gtk_menu_item_set_submenu(GTK_MENU_ITEM(menu_header), menu_widget);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu_bar), menu_header);
  return menu_widget;
}

// WebViewDelegate::TakeFocus in the test webview delegate.
static gboolean HandleFocus(GtkWidget* widget,
                            GdkEventFocus* focus) {
  if (g_handler.get() && g_handler->GetBrowserHwnd()) {
    // Give focus to the browser window.
    g_handler->GetBrowser()->SetFocus(true);
  }

  return TRUE;
}

int main(int argc, char *argv[]) {
  if (!getcwd(szWorkingDir, sizeof (szWorkingDir)))
    return -1;

  GtkWidget* window;

  gtk_init(&argc, &argv);

  CefSettings settings;
  CefRefPtr<CefApp> app;

  // Initialize CEF.
  CefInitialize(settings, app);

  window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), "Atom");
  gtk_window_set_default_size(GTK_WINDOW(window), 800, 600);

  g_signal_connect(window, "focus", G_CALLBACK(&HandleFocus), NULL);

  GtkWidget* vbox = gtk_vbox_new(FALSE, 0);

  gtk_box_pack_start(GTK_BOX(vbox), NULL, FALSE, FALSE, 0);

  g_signal_connect(G_OBJECT(window), "destroy",
                   G_CALLBACK(gtk_widget_destroyed), &window);
  g_signal_connect(G_OBJECT(window), "destroy",
                   G_CALLBACK(destroy), NULL);

  // Create the handler.
  g_handler = new ClientHandler();
  g_handler->SetMainHwnd(vbox);

  // Create the browser view.
  CefWindowInfo window_info;
  CefBrowserSettings browserSettings;

  window_info.SetAsChild(vbox);

  CefBrowser::CreateBrowserSync(window_info,
                                static_cast<CefRefPtr<CefClient> >(g_handler),
                                "", browserSettings);

  gtk_container_add(GTK_CONTAINER(window), vbox);
  gtk_widget_show_all(GTK_WIDGET(window));

  // Install an signal handler so we clean up after ourselves.
  signal(SIGINT, TerminationSignalHandler);
  signal(SIGTERM, TerminationSignalHandler);

  CefRunMessageLoop();

  CefShutdown();

  return 0;
}

// Global functions

std::string AppGetWorkingDirectory() {
  return szWorkingDir;
}

