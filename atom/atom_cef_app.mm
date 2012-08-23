#include "atom_cef_app.h"

void AtomCefApp::OnContextCreated(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     CefRefPtr<CefV8Context> context) {
  fopen("/Users/corey/hi", "w");
}
