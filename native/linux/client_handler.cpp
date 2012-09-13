// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "client_handler.h"
#include <stdio.h>
#include <iostream>
#include <sstream>
#include <string>
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "atom.h"
#include <stdlib.h>
#include <gtk/gtk.h>

using namespace std;

ClientHandler::ClientHandler() :
    m_MainHwnd(NULL), m_BrowserHwnd(NULL) {
}

ClientHandler::~ClientHandler() {
}

bool ClientHandler::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
    CefProcessId source_process, CefRefPtr<CefProcessMessage> message) {
  string name = message->GetName().ToString();
  if (name == "showDevTools") {
    string devtools_url = browser->GetHost()->GetDevToolsURL(true);
    if (!devtools_url.empty())
      browser->GetMainFrame()->ExecuteJavaScript(
          "window.open('" + devtools_url + "');", "about:blank", 0);
  } else
    return false;

  return true;
}

void ClientHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  AutoLock lock_scope(this);
  if (!m_Browser.get()) {
    // We need to keep the main child window, but not popup windows
    m_Browser = browser;
    m_BrowserId = browser->GetIdentifier();
  }
}

bool ClientHandler::DoClose(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  if (m_BrowserId == browser->GetIdentifier()) {
    // Since the main window contains the browser window, we need to close
    // the parent window instead of the browser window.
    CloseMainWindow();

    // Return true here so that we can skip closing the browser window
    // in this pass. (It will be destroyed due to the call to close
    // the parent above.)
    return true;
  }

  // A popup browser window is not contained in another window, so we can let
  // these windows close by themselves.
  return false;
}

void ClientHandler::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  // Free the browser pointer so that the browser can be destroyed
  if (m_BrowserId == browser->GetIdentifier())
    m_Browser = NULL;
}

void ClientHandler::OnLoadStart(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame) {
  REQUIRE_UI_THREAD();

}

void ClientHandler::OnLoadEnd(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame, int httpStatusCode) {
  REQUIRE_UI_THREAD();

}

bool ClientHandler::OnLoadError(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame, ErrorCode errorCode, const CefString& failedUrl,
    CefString& errorText) {
  REQUIRE_UI_THREAD();

  if (errorCode == ERR_CACHE_MISS) {
    // Usually caused by navigating to a page with POST data via back or
    // forward buttons.
    errorText = "<html><head><title>Expired Form Data</title></head>"
        "<body><h1>Expired Form Data</h1>"
        "<h2>Your form request has expired. "
        "Click reload to re-submit the form data.</h2></body>"
        "</html>";
  } else {
    // All other messages.
    stringstream ss;
    ss << "<html><head><title>Load Failed</title></head>"
        "<body><h1>Load Failed</h1>"
        "<h2>Load of URL " << string(failedUrl) << " failed with error code "
        << static_cast<int>(errorCode) << ".</h2></body>"
            "</html>";
    errorText = ss.str();
  }

  return false;
}

void ClientHandler::OnNavStateChange(CefRefPtr<CefBrowser> browser,
    bool canGoBack, bool canGoForward) {
  //Intentionally left blank
}

bool ClientHandler::OnConsoleMessage(CefRefPtr<CefBrowser> browser,
    const CefString& message, const CefString& source, int line) {
  REQUIRE_UI_THREAD();
  cout << string(message) << endl;
  return false;
}

void ClientHandler::OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame, CefRefPtr<CefDOMNode> node) {
  REQUIRE_UI_THREAD();
}

void ClientHandler::SetWindow(GtkWidget* widget) {
  window = widget;
}

void ClientHandler::SetMainHwnd(CefWindowHandle hwnd) {
  AutoLock lock_scope(this);
  m_MainHwnd = hwnd;
}

// ClientHandler::ClientLifeSpanHandler implementation
bool ClientHandler::OnBeforePopup(CefRefPtr<CefBrowser> parentBrowser,
    const CefPopupFeatures& popupFeatures, CefWindowInfo& windowInfo,
    const CefString& url, CefRefPtr<CefClient>& client,
    CefBrowserSettings& settings) {
  REQUIRE_UI_THREAD();

  return false;
}

void ClientHandler::OnAddressChange(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame, const CefString& url) {
  //Intentionally left blank
}

void ClientHandler::OnTitleChange(CefRefPtr<CefBrowser> browser,
    const CefString& title) {
  REQUIRE_UI_THREAD();

  string titleStr(title);

  size_t inHomeDir;
  string home = getenv("HOME");
  inHomeDir = titleStr.find(home);
  if (inHomeDir == 0) {
    titleStr = titleStr.substr(home.length());
    titleStr.insert(0, "~");
  }

  size_t lastSlash;
  lastSlash = titleStr.rfind("/");

  string formatted;
  if (lastSlash != string::npos && lastSlash + 1 < titleStr.length()) {
    formatted.append(titleStr, lastSlash + 1, titleStr.length() - lastSlash);
    formatted.append(" (");
    formatted.append(titleStr, 0, lastSlash);
    formatted.append(")");
  } else
    formatted.append(titleStr);
  formatted.append(" - atom");

  GtkWidget* window = gtk_widget_get_ancestor(
      GTK_WIDGET(browser->GetHost()->GetWindowHandle()), GTK_TYPE_WINDOW);
  gtk_window_set_title(GTK_WINDOW(window), formatted.c_str());
}

void ClientHandler::SendNotification(NotificationType type) {
  // TODO(port): Implement this method.
}

void ClientHandler::CloseMainWindow() {
  // TODO(port): Close main window.
}
