#ifndef CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
#define CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
#pragma once

#include "include/cef_app.h"

class AtomCefApp : public CefApp, 
                   public CefRenderProcessHandler {
                                          
  // CefApp methods
  virtual CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() OVERRIDE { return this; }

  // CefRenderProcessHandler methods
  virtual void OnWebKitInitialized() OVERRIDE;
  virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefRefPtr<CefV8Context> context) OVERRIDE;
  
  IMPLEMENT_REFCOUNTING(AtomCefApp);
};

#endif  // CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
