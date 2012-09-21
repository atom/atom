#ifndef CLIENT_HANDLER_H_
#define CLIENT_HANDLER_H_
#pragma once

#include <map>
#include <string>
#include "include/cef_client.h"
#include "util.h"

// ClientHandler implementation.
class ClientHandler: public CefClient,
    public CefLifeSpanHandler,
    public CefLoadHandler,
    public CefDisplayHandler,
    public CefFocusHandler {
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

  virtual bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
      CefProcessId source_process, CefRefPtr<CefProcessMessage> message)
          OVERRIDE;

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

  // The child browser window
  CefRefPtr<CefBrowser> m_Browser;

  // The main frame window handle
  CefWindowHandle m_MainHwnd;

  // The child browser window handle
  CefWindowHandle m_BrowserHwnd;

  // The child browser id
  int m_BrowserId;

  // Include the default reference counting implementation.
IMPLEMENT_REFCOUNTING(ClientHandler)
  ;
  // Include the default locking implementation.
IMPLEMENT_LOCKING(ClientHandler)
  ;
};

#endif
