#include "atom_cef_render_process_handler.h"
#import "native/v8_extensions/atom.h"
#import "native/v8_extensions/native.h"
#import "native/v8_extensions/onig_reg_exp.h"
#import "native/v8_extensions/onig_scanner.h"
#import "native/v8_extensions/git.h"
#import "native/v8_extensions/tags.h"
#import "native/message_translation.h"
#import "path_watcher.h"
#include <iostream>

void AtomCefRenderProcessHandler::OnWebKitInitialized() {
  new v8_extensions::OnigRegExp();
  new v8_extensions::OnigScanner();
  new v8_extensions::Git();
  new v8_extensions::Tags();
}

void AtomCefRenderProcessHandler::OnContextCreated(CefRefPtr<CefBrowser> browser,
                                                   CefRefPtr<CefFrame> frame,
                                                   CefRefPtr<CefV8Context> context) {
  v8_extensions::Atom::CreateContextBinding(context);
  v8_extensions::Native::CreateContextBinding(context);
}

void AtomCefRenderProcessHandler::OnContextReleased(CefRefPtr<CefBrowser> browser,
                                                    CefRefPtr<CefFrame> frame,
                                                    CefRefPtr<CefV8Context> context) {
  [PathWatcher removePathWatcherForContext:context];
}

bool AtomCefRenderProcessHandler::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                                           CefProcessId source_process,
                                                           CefRefPtr<CefProcessMessage> message) {
  std::string name = message->GetName().ToString();

  if (name == "reload") {
    Reload(browser);
    return true;
  }
  else if (name == "shutdown") {
      Shutdown(browser);
      return true;
  }
  else {
    return CallMessageReceivedHandler(browser->GetMainFrame()->GetV8Context(), message);
  }
}

void AtomCefRenderProcessHandler::Reload(CefRefPtr<CefBrowser> browser) {
  CefRefPtr<CefV8Context> context = browser->GetMainFrame()->GetV8Context();
  CefRefPtr<CefV8Value> global = context->GetGlobal();

  context->Enter();
  CefV8ValueList arguments;

  CefRefPtr<CefV8Value> reloadFunction = global->GetValue("reload");
  reloadFunction->ExecuteFunction(global, arguments);
  if (!reloadFunction->IsFunction() || reloadFunction->HasException()) {
    browser->ReloadIgnoreCache();
  }
  context->Exit();
}

void AtomCefRenderProcessHandler::Shutdown(CefRefPtr<CefBrowser> browser) {
    CefRefPtr<CefV8Context> context = browser->GetMainFrame()->GetV8Context();
    CefRefPtr<CefV8Value> global = context->GetGlobal();

    context->Enter();
    CefV8ValueList arguments;
    CefRefPtr<CefV8Value> shutdownFunction = global->GetValue("shutdown");
    shutdownFunction->ExecuteFunction(global, arguments);
    context->Exit();
}

bool AtomCefRenderProcessHandler::CallMessageReceivedHandler(CefRefPtr<CefV8Context> context, CefRefPtr<CefProcessMessage> message) {
  context->Enter();

  CefRefPtr<CefV8Value> atom = context->GetGlobal()->GetValue("atom");
  CefRefPtr<CefV8Value> receiveFn = atom->GetValue("receiveMessageFromBrowserProcess");

  CefV8ValueList arguments;
  arguments.push_back(CefV8Value::CreateString(message->GetName().ToString()));

  CefRefPtr<CefListValue> messageArguments = message->GetArgumentList();
  if (messageArguments->GetSize() > 0) {
    CefRefPtr<CefV8Value> data = CefV8Value::CreateArray(messageArguments->GetSize());
    TranslateList(messageArguments, data);
    arguments.push_back(data);
  }

  receiveFn->ExecuteFunction(atom, arguments);
  context->Exit();

  if (receiveFn->HasException()) {
    std::cout << "ERROR: Exception in JS receiving message " << message->GetName().ToString() << "\n";
    return false;
  }
  else {
    return true;
  }
}
