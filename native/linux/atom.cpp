// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <gtk/gtk.h>
#include <unistd.h>
#include <string>
#include "atom.h"
#include "atom_cef_app.h"
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_runnable.h"
#include "client_handler.h"
#include "onig_regexp_extension.h"
#include "atom_handler.h"
#include "io_utils.h"

char* szWorkingDir; // The current working directory

const char* szPath; // The folder the application is in

const char* szPathToOpen; // The file to open

CefRefPtr<ClientHandler> g_handler;

void AppGetSettings(CefSettings& settings, CefRefPtr<CefApp>& app) {
  CefString(&settings.cache_path) = "";
  CefString(&settings.user_agent) = "";
  CefString(&settings.product_version) = "";
  CefString(&settings.locale) = "";
  CefString(&settings.log_file) = "";
  CefString(&settings.javascript_flags) = "";

  settings.remote_debugging_port = 9090;
  settings.log_severity = LOGSEVERITY_ERROR;
}

void destroy(void) {
  CefQuitMessageLoop();
}

void TerminationSignalHandler(int signatl) {
  destroy();
}

// WebViewDelegate::TakeFocus in the test webview delegate.
static gboolean HandleFocus(GtkWidget* widget, GdkEventFocus* focus) {
  if (g_handler.get() && g_handler->GetBrowserHwnd()) {
    // Give focus to the browser window.
    g_handler->GetBrowser()->GetHost()->SetFocus(true);
  }

  return TRUE;
}

int main(int argc, char *argv[]) {
  CefMainArgs main_args(argc, argv);
  szWorkingDir = get_current_dir_name();
  if (szWorkingDir == NULL)
    return -1;

  std::string appDir = io_util_app_directory();
  if (appDir.empty())
    return -1;

  szPath = appDir.c_str();

  std::string pathToOpen;
  if (argc >= 2) {
    if (argv[1][0] != '/') {
      pathToOpen.append(szWorkingDir);
      pathToOpen.append("/");
      pathToOpen.append(argv[1]);
    } else
      pathToOpen.append(argv[1]);
  } else
    pathToOpen.append(szWorkingDir);
  szPathToOpen = pathToOpen.c_str();

  GtkWidget* window;

  gtk_init(&argc, &argv);

  CefSettings settings;
  CefRefPtr<CefApp> app(new AtomCefApp);

  AppGetSettings(settings, app);
  CefInitialize(main_args, settings, app.get());

  window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), "atom");
  gtk_window_set_default_size(GTK_WINDOW(window), 800, 600);
  gtk_window_maximize(GTK_WINDOW(window));

  g_signal_connect(window, "focus", G_CALLBACK(&HandleFocus), NULL);

  GtkWidget* vbox = gtk_vbox_new(FALSE, 0);

  g_signal_connect(G_OBJECT(window), "destroy",
      G_CALLBACK(gtk_widget_destroyed), &window);
  g_signal_connect(G_OBJECT(window), "destroy", G_CALLBACK(destroy), NULL);

  // Create the handler.
  g_handler = new ClientHandler();
  g_handler->SetMainHwnd(vbox);
  g_handler->SetWindow(window);

  //new OnigRegexpExtension();
  //new AtomHandler();

  // Create the browser view.
  CefWindowInfo window_info;
  CefBrowserSettings browserSettings;

  window_info.SetAsChild(vbox);

  std::string path = io_utils_real_app_path("/static/index.html");
  if (path.empty())
    return -1;

  std::string resolved("file://");
  resolved.append(path);
  resolved.append("?bootstrapScript=window-bootstrap");
  resolved.append("&pathToOpen=");
  resolved.append(PathToOpen());

  CefBrowserHost::CreateBrowserSync(window_info, g_handler.get(), resolved,
      browserSettings);

  gtk_container_add(GTK_CONTAINER(window), vbox);
  gtk_widget_show_all(GTK_WIDGET(window));

  GdkPixbuf *pixbuf;
  GError *error = NULL;
  std::string iconPath;
  iconPath.append(szPath);
  iconPath.append("/atom.png");
  pixbuf = gdk_pixbuf_new_from_file(iconPath.c_str(), &error);
  if (pixbuf)
    gtk_window_set_icon(GTK_WINDOW(window), pixbuf);

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

std::string AppPath() {
  return szPath;
}

std::string PathToOpen() {
  return szPathToOpen;
}
