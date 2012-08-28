#include "atom_cef_app.h"
#import "native/v8_extensions/atom.h"
#import "native/v8_extensions/native.h"
#import "native/v8_extensions/onig_reg_exp.h"
#include <iostream>

void AtomCefApp::OnWebKitInitialized() {
  new v8_extensions::Atom();
  new v8_extensions::Native();
  new v8_extensions::OnigRegExp();  
}

void AtomCefApp::OnContextCreated(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     CefRefPtr<CefV8Context> context) {
#ifdef RESOURCE_PATH
  CefRefPtr<CefV8Value> resourcePath = CefV8Value::CreateString(RESOURCE_PATH);
#else
  CefRefPtr<CefV8Value> resourcePath = CefV8Value::CreateString([[[NSBundle mainBundle] resourcePath] UTF8String]);
#endif

  CefRefPtr<CefV8Value> global = context->GetGlobal();  
  CefRefPtr<CefV8Value> atom = global->GetValue("atom");
  atom->SetValue("resourcePath", resourcePath, V8_PROPERTY_ATTRIBUTE_NONE);
}

bool AtomCefApp::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                          CefProcessId source_process,
                                          CefRefPtr<CefProcessMessage> message) {
	if (message->GetName().ToString() == "reload") {
		Reload(browser);
	}

  return true;
}

void AtomCefApp::Reload(CefRefPtr<CefBrowser> browser) {
	CefRefPtr<CefV8Context> context = browser->GetMainFrame()->GetV8Context();
	CefRefPtr<CefV8Value> global = context->GetGlobal();

	context->Enter();
	CefV8ValueList arguments;

	CefRefPtr<CefV8Value> reloadFunction = global->GetValue("reload");
//	reloadFunction->ExecuteFunction(global, arguments);
//	if (reloadFunction->HasException()) {
		browser->ReloadIgnoreCache();
//	}
	context->Exit();
}