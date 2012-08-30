// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <sstream>
#include <iostream>
#include "include/cef_path_util.h"
#include "include/cef_process_util.h"
#include "include/cef_runnable.h"
#include "native/atom_cef_client.h"
#include "cef_v8.h"

AtomCefClient::AtomCefClient(){

}

AtomCefClient::~AtomCefClient() {
}


bool AtomCefClient::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                             CefProcessId source_process,
                                             CefRefPtr<CefProcessMessage> message) {
  std::string name = message->GetName().ToString();
  CefRefPtr<CefListValue> argumentList = message->GetArgumentList();
  int messageId = argumentList->GetInt(0);

  if (name == "open") {
    bool hasArguments = argumentList->GetSize() > 1;
    hasArguments ? Open(argumentList->GetString(1)) : Open();
    return true;
  }

  if (name == "newWindow") {
    NewWindow();
    return true;
  }

  if (name == "toggleDevTools") {
    ToggleDevTools(browser);
    return true;
  }

  if (name == "confirm") {
    std::string message = argumentList->GetString(1).ToString();
    std::string detailedMessage = argumentList->GetString(2).ToString();
    std::vector<std::string> buttonLabels(argumentList->GetSize() - 3);
    for (int i = 3; i < argumentList->GetSize(); i++) {
      buttonLabels[i - 3] = argumentList->GetString(i).ToString();
    }

    Confirm(messageId, message, detailedMessage, buttonLabels, browser);
    return true;
  }

  if (name == "showSaveDialog") {
    ShowSaveDialog(messageId, browser);
    return true;
  }

  return false;
}


void AtomCefClient::OnBeforeContextMenu(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefContextMenuParams> params,
    CefRefPtr<CefMenuModel> model) {

  model->Clear();
  model->AddItem(MENU_ID_USER_FIRST, "&Toggle DevTools");
}

bool AtomCefClient::OnContextMenuCommand(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefContextMenuParams> params,
    int command_id,
    EventFlags event_flags) {

  if (command_id == MENU_ID_USER_FIRST) {
    ToggleDevTools(browser);
    return true;
  }
  else {
    return false;
  }
}

bool AtomCefClient::OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                     const CefString& message,
                                     const CefString& source,
                                     int line) {
  REQUIRE_UI_THREAD();
  std::cout << std::string(message) << "\n";
  return true;
}


bool AtomCefClient::OnKeyEvent(CefRefPtr<CefBrowser> browser,
                               const CefKeyEvent& event,
                               CefEventHandle os_event) {
  if (event.modifiers == KEY_META && event.unmodified_character == 'r') {
    browser->SendProcessMessage(PID_RENDERER, CefProcessMessage::Create("reload"));
  }
  else if (event.modifiers == (KEY_META | KEY_ALT) && event.unmodified_character == 'i') {
    ToggleDevTools(browser);
  }
  else {
    return false;
  }

  return true;
}

void AtomCefClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();


  // this was in cefclient... was there a good reason?
//  if(m_BrowserHwnd == browser->GetWindowHandle()) {
//    // Free the browser pointer so that the browser can be destroyed
//    m_Browser = NULL;
//  }

  m_Browser = NULL;
}

void AtomCefClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  AutoLock lock_scope(this);
  if (!m_Browser.get())   {
    m_Browser = browser;
  }

  GetBrowser()->GetHost()->SetFocus(true);
}

void AtomCefClient::OnLoadError(CefRefPtr<CefBrowser> browser,
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
