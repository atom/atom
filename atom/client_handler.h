// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_CLIENT_HANDLER_H_
#define CEF_TESTS_CEFCLIENT_CLIENT_HANDLER_H_
#pragma once

#include <set>
#include <string>
#include "include/cef_client.h"
#include "atom/util.h"


// ClientHandler implementation.
class ClientHandler : public CefClient,
                      public CefContextMenuHandler,
                      public CefDisplayHandler,
                      public CefKeyboardHandler,
                      public CefLifeSpanHandler,
                      public CefLoadHandler,
                      public CefRequestHandler {
 public:
  ClientHandler();
  virtual ~ClientHandler();


  CefRefPtr<CefBrowser> GetBrowser() { return m_Browser; }
												
  // CefContextMenuHandler methods
	virtual void OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
																	 CefRefPtr<CefFrame> frame,
																	 CefRefPtr<CefContextMenuParams> params,
																	 CefRefPtr<CefMenuModel> model) OVERRIDE;
												
  virtual bool OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefContextMenuParams> params,
                                    int command_id,
                                    EventFlags event_flags) OVERRIDE;

  // CefDisplayHandler methods
  virtual bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                const CefString& message,
                                const CefString& source,
                                int line) OVERRIDE;


  // CefLifeSpanHandler methods
  virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) OVERRIDE;

  // CefLoadHandler methods
	virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) OVERRIDE;
												
  virtual void OnLoadError(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           ErrorCode errorCode,
                           const CefString& errorText,
                           const CefString& failedUrl) OVERRIDE;

 protected:
	// The child browser window
	CefRefPtr<CefBrowser> m_Browser;

  // The main frame window handle
  CefWindowHandle m_MainHwnd;

  // List of open DevTools URLs if not using an external browser window.
  std::set<std::string> m_OpenDevToolsURLs;

	void ShowDevTools(CefRefPtr<CefBrowser> browser);
												
  // Include the default reference counting implementation.
  IMPLEMENT_REFCOUNTING(ClientHandler);

												// Include the default locking implementation.
  IMPLEMENT_LOCKING(ClientHandler);
};

#endif  // CEF_TESTS_CEFCLIENT_CLIENT_HANDLER_H_
