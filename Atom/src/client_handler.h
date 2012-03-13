// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef _CLIENT_HANDLER_H
#define _CLIENT_HANDLER_H

#import "include/cef.h"

@class AtomController;

// ClientHandler implementation.
class ClientHandler : public CefClient,
                      public CefLifeSpanHandler,
                      public CefLoadHandler,
                      public CefRequestHandler,
                      public CefDisplayHandler,
                      public CefFocusHandler,
                      public CefKeyboardHandler,
                      public CefPrintHandler,
                      public CefV8ContextHandler,
                      public CefDragHandler
{
public:
  ClientHandler(id delegate);
  virtual ~ClientHandler();

  // CefClient methods
  virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefLoadHandler> GetLoadHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefRequestHandler> GetRequestHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefFocusHandler> GetFocusHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefPrintHandler> GetPrintHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefV8ContextHandler> GetV8ContextHandler() OVERRIDE
      { return this; }
  virtual CefRefPtr<CefDragHandler> GetDragHandler() OVERRIDE
      { return this; }

  // CefLifeSpanHandler methods
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
 
  // CefRequestHandler methods
  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefRequest> request,
                                   CefString& redirectUrl,
                                   CefRefPtr<CefStreamReader>& resourceStream,
                                   CefRefPtr<CefResponse> response,
                                   int loadFlags) OVERRIDE;


  // CefDisplayHandler methods
  virtual void OnNavStateChange(CefRefPtr<CefBrowser> browser,
                                bool canGoBack,
                                bool canGoForward) OVERRIDE;
  virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
                             const CefString& title) OVERRIDE;
  
  // CefFocusHandler methods.
  virtual void OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefDOMNode> node) OVERRIDE;
  
  virtual bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                const CefString& message,
                                const CefString& source,
                                int line) OVERRIDE;

  // CefKeyboardHandler methods.
  virtual bool OnKeyEvent(CefRefPtr<CefBrowser> browser,
                          KeyEventType type,
                          int code,
                          int modifiers,
                          bool isSystemKey,
                          bool isAfterJavaScript) OVERRIDE;
  
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
  
  CefRefPtr<CefBrowser> GetBrowser() { return m_Browser; }
  CefWindowHandle GetBrowserHwnd() { return m_BrowserHwnd; }

protected:
  // The child browser window
  CefRefPtr<CefBrowser> m_Browser;

  // The main frame window handle
  CefWindowHandle m_MainHwnd;

  // The child browser window handle
  CefWindowHandle m_BrowserHwnd;
  
  id m_delegate;

  // Include the default reference counting implementation.
  IMPLEMENT_REFCOUNTING(ClientHandler);
  // Include the default locking implementation.
  IMPLEMENT_LOCKING(ClientHandler);
};

#endif // _CLIENT_HANDLER_H
