// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <sstream>
#include <iostream>
#include "include/cef_path_util.h"
#include "include/cef_process_util.h"
#include "include/cef_runnable.h"
#include "atom/client_handler.h"

ClientHandler::ClientHandler()
  : m_MainHwnd(NULL) {
}

ClientHandler::~ClientHandler() {
}

void ClientHandler::OnBeforeContextMenu(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefContextMenuParams> params,
    CefRefPtr<CefMenuModel> model) {

  model->AddItem(MENU_ID_USER_FIRST, "&Show DevTools");
  CefString devtools_url = browser->GetHost()->GetDevToolsURL(true);

  // Disable the menu option if DevTools isn't enabled or if a window already open for the current URL.
  if (devtools_url.empty() || m_OpenDevToolsURLs.find(devtools_url) != m_OpenDevToolsURLs.end()) {
    model->SetEnabled(MENU_ID_USER_FIRST, false);
  }
}

bool ClientHandler::OnContextMenuCommand(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefContextMenuParams> params,
    int command_id,
    EventFlags event_flags) {

  if (command_id == MENU_ID_USER_FIRST) {
    printf("show dev tools stub\n");
    return true;
  }
  else {
    return false;
  }
}

bool ClientHandler::OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                     const CefString& message,
                                     const CefString& source,
                                     int line) {
  REQUIRE_UI_THREAD();

	std::cout << std::string(message) << "\n";
	
  return true;
}

void ClientHandler::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  if (browser->IsPopup()) {
    // Remove the record for DevTools popup windows.
    std::set<std::string>::iterator it = m_OpenDevToolsURLs.find(browser->GetMainFrame()->GetURL());
    if (it != m_OpenDevToolsURLs.end())
      m_OpenDevToolsURLs.erase(it);
  }
}

void ClientHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();
	
  AutoLock lock_scope(this);
  if (!m_Browser.get())   {
    m_Browser = browser;
  }
}

void ClientHandler::OnLoadError(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                ErrorCode errorCode,
                                const CefString& errorText,
                                const CefString& failedUrl) {
  REQUIRE_UI_THREAD();

  if (errorCode == ERR_ABORTED) { // Don't display an error for downloaded files.
    return;
	}
  else if (errorCode == ERR_UNKNOWN_URL_SCHEME) { // Don't display an error for external protocols that we allow the OS to handle. See OnProtocolExecution().
    return;
  }
  else {    
    std::stringstream ss;
    ss << "<html><body><h2>Failed to load URL " << std::string(failedUrl) <<
    " with error " << std::string(errorText) << " (" << errorCode <<
    ").</h2></body></html>";
    frame->LoadString(ss.str(), failedUrl);
  }
}

void ClientHandler::ShowDevTools(CefRefPtr<CefBrowser> browser) {
  std::string devtools_url = browser->GetHost()->GetDevToolsURL(true);
  if (!devtools_url.empty()) {
    if (m_OpenDevToolsURLs.find(devtools_url) == m_OpenDevToolsURLs.end()) {
      // Open DevTools in a popup window.
      m_OpenDevToolsURLs.insert(devtools_url);
      browser->GetMainFrame()->ExecuteJavaScript("window.open('" +  devtools_url + "');", "about:blank", 0);
    }
  }
}
