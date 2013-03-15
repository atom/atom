#ifndef ATOM_CEF_APP_H_
#define ATOM_CEF_APP_H_
#pragma once

#include "include/cef_app.h"

#include "atom_cef_render_process_handler.h"

class AtomCefApp : public CefApp {

  virtual CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() OVERRIDE {
    return CefRefPtr<CefRenderProcessHandler>(new AtomCefRenderProcessHandler);
  }

  IMPLEMENT_REFCOUNTING(AtomCefApp);
};

#endif
