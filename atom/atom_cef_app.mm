#include "atom_cef_app.h"
#import <Cocoa/Cocoa.h>


void AtomCefApp::OnWebKitInitialized() {
  NSLog(@"%s", "OnWebKitInitialized");

}

void AtomCefApp::OnContextCreated(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     CefRefPtr<CefV8Context> context) {  
  CefRefPtr<CefV8Value> global = context->GetGlobal();  
  CefRefPtr<CefV8Value> atom = CefV8Value::CreateObject(NULL);
  
#ifdef RESOURCE_PATH
  CefRefPtr<CefV8Value> resourcePath = CefV8Value::CreateString(RESOURCE_PATH);
#else
  CefRefPtr<CefV8Value> resourcePath = CefV8Value::CreateString([[[NSBundle mainBundle] resourcePath] UTF8String]);
#endif
  
  atom->SetValue("resourcePath", resourcePath, V8_PROPERTY_ATTRIBUTE_NONE);    
  global->SetValue("atom", atom, V8_PROPERTY_ATTRIBUTE_NONE);
}
