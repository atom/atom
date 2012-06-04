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


// Define this value to redirect all popup URLs to the main application browser
// window.
// #define TEST_REDIRECT_POPUP_URLS


// ClientHandler implementation.
class ClientHandler : public CefClient,
                      public CefLifeSpanHandler,
                      public CefLoadHandler,
                      public CefDisplayHandler,
                      public CefFocusHandler,
                      public CefKeyboardHandler,
                      public CefPrintHandler,
                      public CefV8ContextHandler,
                      public CefDragHandler,
                      public CefPermissionHandler {
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
  virtual CefRefPtr<CefPermissionHandler> GetPermissionHandler() OVERRIDE {
    return this;
  }

  // CefLifeSpanHandler methods
  virtual bool OnBeforePopup(CefRefPtr<CefBrowser> parentBrowser,
                             const CefPopupFeatures& popupFeatures,
                             CefWindowInfo& windowInfo,
                             const CefString& url,
                             CefRefPtr<CefClient>& client,
                             CefBrowserSettings& settings) OVERRIDE;
  virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) OVERRIDE;
  virtual bool DoClose(CefRefPtr<CefBrowser> browser) OVERRIDE;
  virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) OVERRIDE;

  // CefLoadHandler methods
  virtual void OnLoadStart(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame) OVERRIDE;
  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE;
  virtual bool OnLoadError(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           ErrorCode errorCode,
                           const CefString& failedUrl,
                           CefString& errorText) OVERRIDE;

  // CefDisplayHandler methods
  virtual void OnNavStateChange(CefRefPtr<CefBrowser> browser,
                                bool canGoBack,
                                bool canGoForward) OVERRIDE;
  virtual void OnAddressChange(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefFrame> frame,
                               const CefString& url) OVERRIDE;
  virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
                             const CefString& title) OVERRIDE;
  virtual bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                const CefString& message,
                                const CefString& source,
                                int line) OVERRIDE;

  // CefFocusHandler methods.
  virtual void OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefDOMNode> node) OVERRIDE;

  // CefKeyboardHandler methods.
  virtual bool OnKeyEvent(CefRefPtr<CefBrowser> browser,
                          KeyEventType type,
                          int code,
                          int modifiers,
                          bool isSystemKey,
                          bool isAfterJavaScript) OVERRIDE;

  // CefPrintHandler methods.
  virtual bool GetPrintHeaderFooter(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    const CefPrintInfo& printInfo,
                                    const CefString& url,
                                    const CefString& title,
                                    int currentPage,
                                    int maxPages,
                                    CefString& topLeft,
                                    CefString& topCenter,
                                    CefString& topRight,
                                    CefString& bottomLeft,
                                    CefString& bottomCenter,
                                    CefString& bottomRight) OVERRIDE;

  // CefV8ContextHandler methods
  virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefRefPtr<CefV8Context> context) OVERRIDE;

  // CefDragHandler methods.
  virtual bool OnDragStart(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefDragData> dragData,
                           DragOperationsMask mask) OVERRIDE;
  virtual bool OnDragEnter(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefDragData> dragData,
                           DragOperationsMask mask) OVERRIDE;

  // CefPermissionHandler methods.
  virtual bool OnBeforeScriptExtensionLoad(CefRefPtr<CefBrowser> browser,
                                       CefRefPtr<CefFrame> frame,
                                       const CefString& extensionName) OVERRIDE;

  void SetWindow(GtkWidget* window);
  void SetMainHwnd(CefWindowHandle hwnd);
  CefWindowHandle GetMainHwnd() { return m_MainHwnd; }
  void SetEditHwnd(CefWindowHandle hwnd);
  void SetButtonHwnds(CefWindowHandle backHwnd,
                      CefWindowHandle forwardHwnd,
                      CefWindowHandle reloadHwnd,
                      CefWindowHandle stopHwnd);

  CefRefPtr<CefBrowser> GetBrowser() { return m_Browser; }
  CefWindowHandle GetBrowserHwnd() { return m_BrowserHwnd; }

  std::string GetLogFile();

  // DOM visitors will be called after the associated path is loaded.
  void AddDOMVisitor(const std::string& path, CefRefPtr<CefDOMVisitor> visitor);
  CefRefPtr<CefDOMVisitor> GetDOMVisitor(const std::string& path);

  enum NotificationType {
    NOTIFY_CONSOLE_MESSAGE
  };
  void SendNotification(NotificationType type);
  void CloseMainWindow();

 protected:
  void SetLoading(bool isLoading);
  void SetNavState(bool canGoBack, bool canGoForward);
  
  GtkWidget* window;

  // The child browser window
  CefRefPtr<CefBrowser> m_Browser;

  // The main frame window handle
  CefWindowHandle m_MainHwnd;

  // The child browser window handle
  CefWindowHandle m_BrowserHwnd;

  // The edit window handle
  CefWindowHandle m_EditHwnd;

  // The button window handles
  CefWindowHandle m_BackHwnd;
  CefWindowHandle m_ForwardHwnd;
  CefWindowHandle m_StopHwnd;
  CefWindowHandle m_ReloadHwnd;

  // Support for logging.
  std::string m_LogFile;

  // Support for DOM visitors.
  typedef std::map<std::string, CefRefPtr<CefDOMVisitor> > DOMVisitorMap;
  DOMVisitorMap m_DOMVisitors;

  // True if a form element currently has focus
  bool m_bFormElementHasFocus;

  // Include the default reference counting implementation.
  IMPLEMENT_REFCOUNTING(ClientHandler);
  // Include the default locking implementation.
  IMPLEMENT_LOCKING(ClientHandler);
};

#endif  // CEF_TESTS_CEFCLIENT_CLIENT_HANDLER_H_