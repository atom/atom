#ifndef ATOM_CEF_CLIENT_H_
#define ATOM_CEF_CLIENT_H_
#pragma once

#include <set>
#include <string>
#include "include/cef_client.h"

class AtomCefClient : public CefClient,
                      public CefContextMenuHandler,
                      public CefDisplayHandler,
                      public CefJSDialogHandler,
                      public CefKeyboardHandler,
                      public CefLifeSpanHandler,
                      public CefLoadHandler,
                      public CefRequestHandler {
 public:
  AtomCefClient();
  AtomCefClient(bool handlePasteboardCommands, bool ignoreTitleChanges);
  virtual ~AtomCefClient();

  CefRefPtr<CefBrowser> GetBrowser() { return m_Browser; }

  virtual CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefJSDialogHandler> GetJSDialogHandler() {
    return this;
  }
  virtual CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefLoadHandler> GetLoadHandler() OVERRIDE {
    return this;
  }
  virtual CefRefPtr<CefRequestHandler> GetRequestHandler() OVERRIDE {
    return this;
  }

  virtual bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                        CefProcessId source_process,
                                        CefRefPtr<CefProcessMessage> message) OVERRIDE;


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

  virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
                             const CefString& title) OVERRIDE;

  // CefJsDialogHandlerMethods
  virtual bool OnBeforeUnloadDialog(CefRefPtr<CefBrowser> browser,
                                    const CefString& message_text,
                                    bool is_reload,
                                    CefRefPtr<CefJSDialogCallback> callback) {
    callback->Continue(true, "");
    return true;
  }

  // CefKeyboardHandler methods
  virtual bool OnKeyEvent(CefRefPtr<CefBrowser> browser,
                          const CefKeyEvent& event,
                          CefEventHandle os_event) OVERRIDE;

  // CefLifeSpanHandler methods
  virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) OVERRIDE;
  virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) OVERRIDE;


  // CefLoadHandler methods
  virtual void OnLoadError(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           ErrorCode errorCode,
                           const CefString& errorText,
                           const CefString& failedUrl) OVERRIDE;

  void BeginTracing();
  void EndTracing();

  bool Save(const std::string& path, const std::string& data);
  void RestartRendererProcess(CefRefPtr<CefBrowser> browser);

 protected:
  CefRefPtr<CefBrowser> m_Browser;
  bool m_HandlePasteboardCommands = false;
  bool m_IgnoreTitleChanges = false;

  void FocusNextWindow();
  void FocusPreviousWindow();
  void Open(std::string path);
  void Open();
  void OpenDev(std::string path);
  void OpenDev();
  void NewWindow();
  void ToggleDevTools(CefRefPtr<CefBrowser> browser);
  void ShowDevTools(CefRefPtr<CefBrowser> browser);
  void Confirm(int replyId,
               std::string message,
               std::string detailedMessage,
               std::vector<std::string> buttonLabels,
               CefRefPtr<CefBrowser> browser);
  void ShowSaveDialog(int replyId, CefRefPtr<CefBrowser> browser);
  CefRefPtr<CefListValue> CreateReplyDescriptor(int replyId, int callbackIndex);
  void Exit(int status);
  void Log(const char *message);
  void Show(CefRefPtr<CefBrowser> browser);
  void ToggleFullScreen(CefRefPtr<CefBrowser> browser);
  void GetVersion(int replyId, CefRefPtr<CefBrowser> browser);

  IMPLEMENT_REFCOUNTING(AtomCefClient);
  IMPLEMENT_LOCKING(AtomCefClient);
};

#endif
