#ifndef ATOM_CEF_RENDER_PROCESS_HANDLER_H_
#define ATOM_CEF_RENDER_PROCESS_HANDLER_H_
#pragma once

#include "include/cef_app.h"

class AtomCefRenderProcessHandler : public CefRenderProcessHandler {

  virtual void OnWebKitInitialized() OVERRIDE;
  virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefRefPtr<CefV8Context> context) OVERRIDE;
  virtual void OnContextReleased(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 CefRefPtr<CefV8Context> context) OVERRIDE;
  virtual bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                       CefProcessId source_process,
                                       CefRefPtr<CefProcessMessage> message) OVERRIDE;
  virtual void OnWorkerContextCreated(int worker_id,
                                      const CefString& url,
                                      CefRefPtr<CefV8Context> context) OVERRIDE;
  virtual void OnWorkerContextReleased(int worker_id,
                                       const CefString& url,
                                       CefRefPtr<CefV8Context> context) OVERRIDE;
  virtual void OnWorkerUncaughtException(int worker_id,
                                         const CefString& url,
                                         CefRefPtr<CefV8Context> context,
                                         CefRefPtr<CefV8Exception> exception,
                                         CefRefPtr<CefV8StackTrace> stackTrace) OVERRIDE;

  void Reload(CefRefPtr<CefBrowser> browser);
  void Shutdown(CefRefPtr<CefBrowser> browser);
  bool CallMessageReceivedHandler(CefRefPtr<CefV8Context> context, CefRefPtr<CefProcessMessage> message);
  void InjectExtensionsIntoV8Context(CefRefPtr<CefV8Context> context);

  IMPLEMENT_REFCOUNTING(AtomCefRenderProcessHandler);
};

#endif  // ATOM_CEF_RENDER_PROCESS_HANDLER_H_

