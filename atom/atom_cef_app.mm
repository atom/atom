#include "atom_cef_app.h"
#import <Cocoa/Cocoa.h>


void AtomCefApp::OnWebKitInitialized() {
  NSLog(@"%s", "OnWebKitInitialized");

}

void AtomCefApp::OnContextCreated(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     CefRefPtr<CefV8Context> context) {
  NSLog(@"%s", "OnContextCreated");
}
