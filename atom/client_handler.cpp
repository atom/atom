// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "atom/client_handler.h"
#include <algorithm>
#include <stdio.h>
#include <sstream>
#include <string>
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_path_util.h"
#include "include/cef_process_util.h"
#include "include/cef_runnable.h"
#include "include/wrapper/cef_stream_resource_handler.h"

ClientHandler::ClientHandler()
  : m_MainHwnd(NULL),
    m_BrowserId(0),
    m_EditHwnd(NULL),
    m_BackHwnd(NULL),
    m_ForwardHwnd(NULL),
    m_StopHwnd(NULL),
    m_ReloadHwnd(NULL),
    m_bFocusOnEditableField(false) {
  CreateProcessMessageDelegates(process_message_delegates_);
  CreateRequestDelegates(request_delegates_);

  // Read command line settings.
  CefRefPtr<CefCommandLine> command_line =
      CefCommandLine::GetGlobalCommandLine();

  if (command_line->HasSwitch("url"))
    m_StartupURL = command_line->GetSwitchValue("url");
  if (m_StartupURL.empty())
    m_StartupURL = "http://www.google.com/";

  m_bExternalDevTools = command_line->HasSwitch("external-devtools");
}

ClientHandler::~ClientHandler() {
}

bool ClientHandler::OnProcessMessageReceived(
    CefRefPtr<CefBrowser> browser,
    CefProcessId source_process,
    CefRefPtr<CefProcessMessage> message) {

  return false;
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
    ShowDevTools(browser);
    return true;
  }
  else {
    return false;
  }
}

void ClientHandler::OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                         bool isLoading,
                                         bool canGoBack,
                                         bool canGoForward) {
  REQUIRE_UI_THREAD();
}

bool ClientHandler::OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                     const CefString& message,
                                     const CefString& source,
                                     int line) {
  REQUIRE_UI_THREAD();

  return false;
}

void ClientHandler::OnBeforeDownload(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefDownloadItem> download_item,
    const CefString& suggested_name,
    CefRefPtr<CefBeforeDownloadCallback> callback) {
  REQUIRE_UI_THREAD();
}

void ClientHandler::OnDownloadUpdated(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefDownloadItem> download_item,
    CefRefPtr<CefDownloadItemCallback> callback) {
  REQUIRE_UI_THREAD();
}

void ClientHandler::OnRequestGeolocationPermission(
      CefRefPtr<CefBrowser> browser,
      const CefString& requesting_url,
      int request_id,
      CefRefPtr<CefGeolocationCallback> callback) {
}

bool ClientHandler::OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                                  const CefKeyEvent& event,
                                  CefEventHandle os_event,
                                  bool* is_keyboard_shortcut) {

  return false;
}

void ClientHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  AutoLock lock_scope(this);
  if (!m_Browser.get())   {
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

  if (m_BrowserId == browser->GetIdentifier()) {    
    m_Browser = NULL; // Free the browser pointer so that the browser can be destroyed
  } 
  else if (browser->IsPopup()) {
    // Remove the record for DevTools popup windows.
    std::set<std::string>::iterator it = m_OpenDevToolsURLs.find(browser->GetMainFrame()->GetURL());
    if (it != m_OpenDevToolsURLs.end())
      m_OpenDevToolsURLs.erase(it);
  }
}

void ClientHandler::OnLoadStart(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame) {
  REQUIRE_UI_THREAD();
}

void ClientHandler::OnLoadEnd(CefRefPtr<CefBrowser> browser,
                              CefRefPtr<CefFrame> frame,
                              int httpStatusCode) {
  REQUIRE_UI_THREAD();
}

void ClientHandler::OnLoadError(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                ErrorCode errorCode,
                                const CefString& errorText,
                                const CefString& failedUrl) {
  REQUIRE_UI_THREAD();

  if (errorCode == ERR_ABORTED) // Don't display an error for downloaded files.
    return;
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

void ClientHandler::OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
                                              TerminationStatus status) {
  // Load the startup URL if that's not the website that we terminated on.
  CefRefPtr<CefFrame> frame = browser->GetMainFrame();
  std::string url = frame->GetURL();
  std::transform(url.begin(), url.end(), url.begin(), tolower);

  std::string startupURL = GetStartupURL();
  if (url.find(startupURL) != 0)
    frame->LoadURL(startupURL);
}

CefRefPtr<CefResourceHandler> ClientHandler::GetResourceHandler(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      CefRefPtr<CefRequest> request) {

  return NULL;
}

void ClientHandler::OnProtocolExecution(CefRefPtr<CefBrowser> browser,
                                        const CefString& url,
                                        bool& allow_os_execution) {
  std::string urlStr = url;

  // Allow OS execution of Spotify URIs.
  if (urlStr.find("spotify:") == 0)
    allow_os_execution = true;
}

void ClientHandler::SetMainHwnd(CefWindowHandle hwnd) {
  AutoLock lock_scope(this);
  m_MainHwnd = hwnd;
}

void ClientHandler::SetEditHwnd(CefWindowHandle hwnd) {
  AutoLock lock_scope(this);
  m_EditHwnd = hwnd;
}

void ClientHandler::SetButtonHwnds(CefWindowHandle backHwnd,
                                   CefWindowHandle forwardHwnd,
                                   CefWindowHandle reloadHwnd,
                                   CefWindowHandle stopHwnd) {
  AutoLock lock_scope(this);
  m_BackHwnd = backHwnd;
  m_ForwardHwnd = forwardHwnd;
  m_ReloadHwnd = reloadHwnd;
  m_StopHwnd = stopHwnd;
}

std::string ClientHandler::GetLogFile() {
  AutoLock lock_scope(this);
  return m_LogFile;
}

void ClientHandler::SetLastDownloadFile(const std::string& fileName) {
  AutoLock lock_scope(this);
  m_LastDownloadFile = fileName;
}

std::string ClientHandler::GetLastDownloadFile() {
  AutoLock lock_scope(this);
  return m_LastDownloadFile;
}

void ClientHandler::ShowDevTools(CefRefPtr<CefBrowser> browser) {
  std::string devtools_url = browser->GetHost()->GetDevToolsURL(true);
  if (!devtools_url.empty()) {
    if (m_bExternalDevTools) {
      LaunchExternalBrowser(devtools_url); // Open DevTools in an external browser window.
    } 
    else if (m_OpenDevToolsURLs.find(devtools_url) == m_OpenDevToolsURLs.end()) {      
      m_OpenDevToolsURLs.insert(devtools_url); // Open DevTools in a popup window.
      browser->GetMainFrame()->ExecuteJavaScript("window.open('" +  devtools_url + "');", "about:blank", 0);
    }
  }
}

// static
void ClientHandler::LaunchExternalBrowser(const std::string& url) {
  if (CefCurrentlyOn(TID_PROCESS_LAUNCHER)) {
    // Retrieve the current executable path.
    CefString file_exe;
    if (!CefGetPath(PK_FILE_EXE, file_exe))
      return;

    // Create the command line.
    CefRefPtr<CefCommandLine> command_line =
        CefCommandLine::CreateCommandLine();
    command_line->SetProgram(file_exe);
    command_line->AppendSwitchWithValue("url", url);

    // Launch the process.
    CefLaunchProcess(command_line);
  } else {
    // Execute on the PROCESS_LAUNCHER thread.
    CefPostTask(TID_PROCESS_LAUNCHER,
        NewCefRunnableFunction(&ClientHandler::LaunchExternalBrowser, url));
  }
}

// static
void ClientHandler::CreateProcessMessageDelegates(
      ProcessMessageDelegateSet& delegates) {
}

// static
void ClientHandler::CreateRequestDelegates(RequestDelegateSet& delegates) {
}
