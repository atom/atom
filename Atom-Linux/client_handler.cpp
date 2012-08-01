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
#include "native_handler.h"
#include <stdlib.h>
#include <gtk/gtk.h>

ClientHandler::ClientHandler() :
    m_MainHwnd(NULL), m_BrowserHwnd(NULL) {
}

ClientHandler::~ClientHandler() {
}

void ClientHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  AutoLock lock_scope(this);
  if (!m_Browser.get()) {
    // We need to keep the main child window, but not popup windows
    m_Browser = browser;
    m_BrowserHwnd = browser->GetWindowHandle();
  }
}

bool ClientHandler::DoClose(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  if (m_BrowserHwnd == browser->GetWindowHandle()) {
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

  if (m_BrowserHwnd == browser->GetWindowHandle()) {
    // Free the browser pointer so that the browser can be destroyed
    m_Browser = NULL;
  }
}

void ClientHandler::OnLoadStart(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame) {
  REQUIRE_UI_THREAD();

  if (m_BrowserHwnd == browser->GetWindowHandle() && frame->IsMain()) {
    CefRefPtr<CefV8Context> context = frame->GetV8Context();
    CefRefPtr<CefV8Value> global = context->GetGlobal();
    context->Enter();

    CefRefPtr<CefV8Value> windowNumber = CefV8Value::CreateInt(0);
    global->SetValue("$windowNumber", windowNumber, V8_PROPERTY_ATTRIBUTE_NONE);

    std::string path;
    if (m_nativeHandler)
      path = m_nativeHandler->path;
    else
      path.append(PathToOpen());

    CefRefPtr<CefV8Value> pathToOpen = CefV8Value::CreateString(path);
    global->SetValue("$pathToOpen", pathToOpen, V8_PROPERTY_ATTRIBUTE_NONE);

    CefRefPtr<NativeHandler> nativeHandler = new NativeHandler();
    nativeHandler->window = window;
    nativeHandler->path = path;
    global->SetValue("$native", nativeHandler->object,
        V8_PROPERTY_ATTRIBUTE_NONE);
    m_nativeHandler = nativeHandler;

    CefRefPtr<CefV8Value> atom = CefV8Value::CreateObject(NULL, NULL);
    global->SetValue("atom", atom, V8_PROPERTY_ATTRIBUTE_NONE);

    std::string relativePath(AppPath());
    relativePath.append("/..");
    char* realLoadPath;
    realLoadPath = realpath(relativePath.c_str(), NULL);
    if (realLoadPath != NULL) {
      std::string resolvedLoadPath(realLoadPath);
      free(realLoadPath);

      CefRefPtr<CefV8Value> loadPath = CefV8Value::CreateString(
          resolvedLoadPath);
      atom->SetValue("loadPath", loadPath, V8_PROPERTY_ATTRIBUTE_NONE);
    }

    CefRefPtr<CefV8Value> bootstrapScript = CefV8Value::CreateString(
        "single-window-bootstrap");
    global->SetValue("$bootstrapScript", bootstrapScript,
        V8_PROPERTY_ATTRIBUTE_NONE);

    context->Exit();
  }
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
    std::stringstream ss;
    ss << "<html><head><title>Load Failed</title></head>"
        "<body><h1>Load Failed</h1>"
        "<h2>Load of URL " << std::string(failedUrl)
        << " failed with error code " << static_cast<int>(errorCode)
        << ".</h2></body>"
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
  std::cout << std::string(message) << std::endl;
  return false;
}

void ClientHandler::OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame, CefRefPtr<CefDOMNode> node) {
  REQUIRE_UI_THREAD();
}

bool ClientHandler::OnKeyEvent(CefRefPtr<CefBrowser> browser, KeyEventType type,
    int code, int modifiers, bool isSystemKey, bool isAfterJavaScript) {
  REQUIRE_UI_THREAD();

  return false;
}

bool ClientHandler::GetPrintHeaderFooter(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame, const CefPrintInfo& printInfo,
    const CefString& url, const CefString& title, int currentPage, int maxPages,
    CefString& topLeft, CefString& topCenter, CefString& topRight,
    CefString& bottomLeft, CefString& bottomCenter, CefString& bottomRight) {
  REQUIRE_UI_THREAD();

  // Place the page title at top left
  topLeft = title;
  // Place the page URL at top right
  topRight = url;

  // Place "Page X of Y" at bottom center
  std::stringstream strstream;
  strstream << "Page " << currentPage << " of " << maxPages;
  bottomCenter = strstream.str();

  return false;
}

void ClientHandler::OnContextCreated(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context) {
  REQUIRE_UI_THREAD();
}

bool ClientHandler::OnDragStart(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefDragData> dragData, DragOperationsMask mask) {
  REQUIRE_UI_THREAD();

  return false;
}

bool ClientHandler::OnDragEnter(CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefDragData> dragData, DragOperationsMask mask) {
  REQUIRE_UI_THREAD();

  return false;
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

  std::string titleStr(title);

  size_t inHomeDir;
  std::string home = getenv("HOME");
  inHomeDir = titleStr.find(home);
  if (inHomeDir == 0) {
    titleStr = titleStr.substr(home.length());
    titleStr.insert(0, "~");
  }

  size_t lastSlash;
  lastSlash = titleStr.rfind("/");

  std::string formatted;
  if (lastSlash != std::string::npos && lastSlash + 1 < titleStr.length()) {
    formatted.append(titleStr, lastSlash + 1, titleStr.length() - lastSlash);
    formatted.append(" (");
    formatted.append(titleStr, 0, lastSlash);
    formatted.append(")");
  } else
    formatted.append(titleStr);
  formatted.append(" - atom");

  GtkWidget* window = gtk_widget_get_ancestor(
      GTK_WIDGET(browser->GetWindowHandle()), GTK_TYPE_WINDOW);
  gtk_window_set_title(GTK_WINDOW(window), formatted.c_str());
}

void ClientHandler::SendNotification(NotificationType type) {
  // TODO(port): Implement this method.
}

void ClientHandler::CloseMainWindow() {
  // TODO(port): Close main window.
}
