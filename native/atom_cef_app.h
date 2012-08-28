#ifndef CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
#define CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
#pragma once

#include "include/cef_app.h"

#ifdef PROCESS_HELPER_APP
#include "atom_cef_render_process_handler.h"
#endif

class AtomCefApp : public CefApp {
                                          
  // CefApp methods
  virtual CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() OVERRIDE { 
#ifdef PROCESS_HELPER_APP
    return CefRefPtr<CefRenderProcessHandler>(new AtomCefRenderProcessHandler); 
#else
    return NULL;
#endif
  }
  
  IMPLEMENT_REFCOUNTING(AtomCefApp);
};

#endif  // CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
