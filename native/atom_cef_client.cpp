#include <sstream>
#include <iostream>
#include <assert.h>
#include "include/cef_path_util.h"
#include "include/cef_process_util.h"
#include "include/cef_task.h"
#include "include/cef_runnable.h"
#include "include/cef_trace.h"
#include "cef_types.h"
#include "native/atom_cef_client.h"
#include "cef_v8.h"

#define REQUIRE_UI_THREAD()   assert(CefCurrentlyOn(TID_UI));
#define REQUIRE_IO_THREAD()   assert(CefCurrentlyOn(TID_IO));
#define REQUIRE_FILE_THREAD() assert(CefCurrentlyOn(TID_FILE));

AtomCefClient::AtomCefClient(){
}

AtomCefClient::AtomCefClient(bool handlePasteboardCommands, bool ignoreTitleChanges) {
  m_HandlePasteboardCommands = handlePasteboardCommands;
  m_IgnoreTitleChanges = ignoreTitleChanges;
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
  if (name == "openDev") {
    bool hasArguments = argumentList->GetSize() > 1;
    hasArguments ? OpenDev(argumentList->GetString(1)) : OpenDev();
  }
  else if (name == "newWindow") {
    NewWindow();
  }
  else if (name == "toggleDevTools") {
    ToggleDevTools(browser);
  }
  else if (name == "showDevTools") {
    ShowDevTools(browser);
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
  else if (name == "showSaveDialog") {
    ShowSaveDialog(messageId, browser);
  }
  else if (name == "focus") {
    GetBrowser()->GetHost()->SetFocus(true);
  }
  else if (name == "exit") {
    Exit(argumentList->GetInt(1));
  }
  else if (name == "log") {
    std::string message = argumentList->GetString(1).ToString();
    Log(message.c_str());
  }
  else if (name == "beginTracing") {
    BeginTracing();
  }
  else if (name == "endTracing") {
    EndTracing();
  }
  else if (name == "show") {
    Show(browser);
  }
  else if (name == "toggleFullScreen") {
    ToggleFullScreen(browser);
  }
  else if (name == "getVersion") {
    GetVersion(messageId, browser);
  }
  else if (name == "crash") {
    __builtin_trap();
  }
  else if (name == "restartRendererProcess") {
    RestartRendererProcess(browser);
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
  Log(message.ToString().c_str());
  return true;
}

bool AtomCefClient::OnKeyEvent(CefRefPtr<CefBrowser> browser,
                               const CefKeyEvent& event,
                               CefEventHandle os_event) {
  if (event.modifiers == EVENTFLAG_COMMAND_DOWN && event.unmodified_character == 'r') {
    browser->SendProcessMessage(PID_RENDERER, CefProcessMessage::Create("reload"));
  }
  if (m_HandlePasteboardCommands && event.modifiers == EVENTFLAG_COMMAND_DOWN && event.unmodified_character == 'x') {
    browser->GetFocusedFrame()->Cut();
  }
  if (m_HandlePasteboardCommands && event.modifiers == EVENTFLAG_COMMAND_DOWN && event.unmodified_character == 'c') {
    browser->GetFocusedFrame()->Copy();
  }
  if (m_HandlePasteboardCommands && event.modifiers == EVENTFLAG_COMMAND_DOWN && event.unmodified_character == 'v') {
    browser->GetFocusedFrame()->Paste();
  }
  else if (event.modifiers == (EVENTFLAG_COMMAND_DOWN | EVENTFLAG_ALT_DOWN) && event.unmodified_character == 'i') {
    ToggleDevTools(browser);
  } else if (event.modifiers == EVENTFLAG_COMMAND_DOWN && event.unmodified_character == '`') {
    FocusNextWindow();
  } else if (event.modifiers == (EVENTFLAG_COMMAND_DOWN | EVENTFLAG_SHIFT_DOWN) && event.unmodified_character == '~') {
    FocusPreviousWindow();
  }
  else {
    return false;
  }

  return true;
}

void AtomCefClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
//  REQUIRE_UI_THREAD(); // When uncommented this fails when app is terminated
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

void AtomCefClient::BeginTracing() {
  if (CefCurrentlyOn(TID_UI)) {
    class Client : public CefTraceClient,
    public CefRunFileDialogCallback {
    public:
      explicit Client(CefRefPtr<AtomCefClient> handler)
      : handler_(handler),
      trace_data_("{\"traceEvents\":["),
      first_(true) {
      }

      virtual void OnTraceDataCollected(const char* fragment,
                                        size_t fragment_size) OVERRIDE {
        if (first_)
          first_ = false;
        else
          trace_data_.append(",");
        trace_data_.append(fragment, fragment_size);
      }

      virtual void OnEndTracingComplete() OVERRIDE {
        REQUIRE_UI_THREAD();
        trace_data_.append("]}");

        handler_->GetBrowser()->GetHost()->RunFileDialog(
                                                         FILE_DIALOG_SAVE, CefString(), "/tmp/atom-trace.txt", std::vector<CefString>(),
                                                         this);
      }

      virtual void OnFileDialogDismissed(
                                         CefRefPtr<CefBrowserHost> browser_host,
                                         const std::vector<CefString>& file_paths) OVERRIDE {
        if (!file_paths.empty())
          handler_->Save(file_paths.front(), trace_data_);
      }

    private:
      CefRefPtr<AtomCefClient> handler_;
      std::string trace_data_;
      bool first_;

      IMPLEMENT_REFCOUNTING(Callback);
    };

    CefBeginTracing(new Client(this), CefString());
  } else {
    CefPostTask(TID_UI, NewCefRunnableMethod(this, &AtomCefClient::BeginTracing));
  }
}

void AtomCefClient::EndTracing() {
  if (CefCurrentlyOn(TID_UI)) {
    CefEndTracingAsync();
  } else {
    CefPostTask(TID_UI, NewCefRunnableMethod(this, &AtomCefClient::BeginTracing));
  }
}

bool AtomCefClient::Save(const std::string& path, const std::string& data) {
  FILE* f = fopen(path.c_str(), "w");
  if (!f)
    return false;
  fwrite(data.c_str(), data.size(), 1, f);
  fclose(f);
  return true;
}

void AtomCefClient::RestartRendererProcess(CefRefPtr<CefBrowser> browser) {
  // Navigating to the same URL has the effect of restarting the renderer
  // process, because cefode has overridden ContentBrowserClient's
  // ShouldSwapProcessesForNavigation method.
  CefRefPtr<CefFrame> frame = browser->GetFocusedFrame();
  frame->LoadURL(frame->GetURL());
}
