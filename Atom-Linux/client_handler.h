// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_CLIENT_HANDLER_H_
#define CEF_TESTS_CEFCLIENT_CLIENT_HANDLER_H_
#pragma once

#include <map>
#include <string>
#include "include/cef_client.h"
#include "util.h"
#include "native_handler.h"

// ClientHandler implementation.
class ClientHandler: public CefClient,
    public CefLifeSpanHandler,
    public CefLoadHandler,
    public CefDisplayHandler,
    public CefFocusHandler,
    public CefKeyboardHandler,
    public CefPrintHandler,
    public CefV8ContextHandler,
    public CefDragHandler {
public:
  ClientHandler();
  virtual ~ClientHandler();

  // CefClient methods
  virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefLoadHandler> GetLoadHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefFocusHandler> GetFocusHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefPrintHandler> GetPrintHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefV8ContextHandler> GetV8ContextHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefDragHandler> GetDragHandler() OVERRIDE {
    return this;
  }

  // CefLifeSpanHandler methods
  virtual bool OnBeforePopup(CefRefPtr<CefBrowser> parentBrowser,
      const CefPopupFeatures& popupFeatures, CefWindowInfo& windowInfo,
      const CefString& url, CefRefPtr<CefClient>& client,
      CefBrowserSettings& settings) OVERRIDE;
  virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) OVERRIDE;
  virtual bool DoClose(CefRefPtr<CefBrowser> browser) OVERRIDE;
  virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) OVERRIDE;

  // CefLoadHandler methods
  virtual void OnLoadStart(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame) OVERRIDE;
  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame, int httpStatusCode) OVERRIDE;
  virtual bool OnLoadError(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame, ErrorCode errorCode,
      const CefString& failedUrl, CefString& errorText) OVERRIDE;

  // CefDisplayHandler methods
  virtual void OnNavStateChange(CefRefPtr<CefBrowser> browser, bool canGoBack,
      bool canGoForward) OVERRIDE;
  virtual void OnAddressChange(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame, const CefString& url) OVERRIDE;
  virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
      const CefString& title) OVERRIDE;
  virtual bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
      const CefString& message, const CefString& source, int line) OVERRIDE;

  // CefFocusHandler methods.
  virtual void OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame, CefRefPtr<CefDOMNode> node) OVERRIDE;

  // CefKeyboardHandler methods.
  virtual bool OnKeyEvent(CefRefPtr<CefBrowser> browser, KeyEventType type,
      int code, int modifiers, bool isSystemKey, bool isAfterJavaScript)
          OVERRIDE;

  // CefPrintHandler methods.
  virtual bool GetPrintHeaderFooter(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame, const CefPrintInfo& printInfo,
      const CefString& url, const CefString& title, int currentPage,
      int maxPages, CefString& topLeft, CefString& topCenter,
      CefString& topRight, CefString& bottomLeft, CefString& bottomCenter,
      CefString& bottomRight) OVERRIDE;

  // CefV8ContextHandler methods
  virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context) OVERRIDE;

  // CefDragHandler methods.
  virtual bool OnDragStart(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefDragData> dragData, DragOperationsMask mask) OVERRIDE;
  virtual bool OnDragEnter(CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefDragData> dragData, DragOperationsMask mask) OVERRIDE;

  void SetWindow(GtkWidget* window);
  void SetMainHwnd(CefWindowHandle hwnd);
  CefWindowHandle GetMainHwnd() {
    return m_MainHwnd;
  }
  void SetEditHwnd(CefWindowHandle hwnd);

  CefRefPtr<CefBrowser> GetBrowser() {
    return m_Browser;
  }
  CefWindowHandle GetBrowserHwnd() {
    return m_BrowserHwnd;
  }

  enum NotificationType {
    NOTIFY_CONSOLE_MESSAGE
  };
  void SendNotification(NotificationType type);
  void CloseMainWindow();

protected:

  GtkWidget* window;

  CefRefPtr<NativeHandler> m_nativeHandler;

  // The child browser window
  CefRefPtr<CefBrowser> m_Browser;

  // The main frame window handle
  CefWindowHandle m_MainHwnd;

  // The child browser window handle
  CefWindowHandle m_BrowserHwnd;

  // The edit window handle
  CefWindowHandle m_EditHwnd;

  // Support for logging.
  std::string m_LogFile;

  // Include the default reference counting implementation.
IMPLEMENT_REFCOUNTING(ClientHandler)
  ;
  // Include the default locking implementation.
IMPLEMENT_LOCKING(ClientHandler)
  ;
};

#endif  // CEF_TESTS_CEFCLIENT_CLIENT_HANDLER_H_
