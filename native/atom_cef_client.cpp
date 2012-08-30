#include <sstream>
#include <iostream>
#include <assert.h>
#include "include/cef_path_util.h"
#include "include/cef_process_util.h"
#include "include/cef_task.h"
#include "include/cef_runnable.h"
#include "native/atom_cef_client.h"
#include "cef_v8.h"

#define REQUIRE_UI_THREAD()   assert(CefCurrentlyOn(TID_UI));
#define REQUIRE_IO_THREAD()   assert(CefCurrentlyOn(TID_IO));
#define REQUIRE_FILE_THREAD() assert(CefCurrentlyOn(TID_FILE));

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
  }
  else if (name == "newWindow") {
    NewWindow();
  }
  else if (name == "toggleDevTools") {
    ToggleDevTools(browser);
  }
  else if (name == "confirm") {
    std::string message = argumentList->GetString(1).ToString();
    std::string detailedMessage = argumentList->GetString(2).ToString();
    std::vector<std::string> buttonLabels(argumentList->GetSize() - 3);
    for (int i = 3; i < argumentList->GetSize(); i++) {
      buttonLabels[i - 3] = argumentList->GetString(i).ToString();
    }

    Confirm(messageId, message, detailedMessage, buttonLabels, browser);
  }
  else {
    return false;
  }
  
  return true;
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


// TODO: Ask Marshal. This was in cefclient... was there a good reason?
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
  frame->LoadString(std::string(errorText) + "<br />" + std::string(failedUrl), failedUrl);
}
