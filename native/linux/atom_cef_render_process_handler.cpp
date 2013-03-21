#include "atom_cef_render_process_handler.h"
#include "atom.h"
#include "native_linux.h"
#include "onig_reg_exp.h"
#include "io_utils.h"
#include "message_translation.h"
#include <iostream>

void AtomCefRenderProcessHandler::OnWebKitInitialized() {
  new v8_extensions::Atom();
  new v8_extensions::NativeHandler();
}

void AtomCefRenderProcessHandler::OnContextCreated(
    CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
    CefRefPtr<CefV8Context> context) {
  CefRefPtr<CefV8Value> resourcePath = CefV8Value::CreateString(
      io_util_app_directory());

  CefRefPtr<CefV8Value> global = context->GetGlobal();
  CefRefPtr<CefV8Value> atom = global->GetValue("atom");
  atom->SetValue("resourcePath", resourcePath, V8_PROPERTY_ATTRIBUTE_NONE);
}

bool AtomCefRenderProcessHandler::OnProcessMessageReceived(
    CefRefPtr<CefBrowser> browser, CefProcessId source_process,
    CefRefPtr<CefProcessMessage> message) {
  std::string name = message->GetName().ToString();
  if (name == "reload") {
    Reload(browser);
    return true;
  } else {
    return CallMessageReceivedHandler(browser->GetMainFrame()->GetV8Context(),
        message);
  }
}

void AtomCefRenderProcessHandler::Reload(CefRefPtr<CefBrowser> browser) {
  CefRefPtr<CefV8Context> context = browser->GetMainFrame()->GetV8Context();
  CefRefPtr<CefV8Value> global = context->GetGlobal();

  context->Enter();
  CefV8ValueList arguments;

  CefRefPtr<CefV8Value> reloadFunction = global->GetValue("reload");
  reloadFunction->ExecuteFunction(global, arguments);
  if (reloadFunction->HasException()) {
    browser->ReloadIgnoreCache();
  }
  context->Exit();
}

bool AtomCefRenderProcessHandler::CallMessageReceivedHandler(
    CefRefPtr<CefV8Context> context, CefRefPtr<CefProcessMessage> message) {
  context->Enter();

  CefRefPtr<CefV8Value> atom = context->GetGlobal()->GetValue("atom");
  CefRefPtr<CefV8Value> receiveFn = atom->GetValue(
      "receiveMessageFromBrowserProcess");

  CefV8ValueList arguments;
  arguments.push_back(CefV8Value::CreateString(message->GetName().ToString()));

  CefRefPtr<CefListValue> messageArguments = message->GetArgumentList();
  if (messageArguments->GetSize() > 0) {
    CefRefPtr<CefV8Value> data = CefV8Value::CreateArray(
        messageArguments->GetSize());
    TranslateList(messageArguments, data);
    arguments.push_back(data);
  }

  receiveFn->ExecuteFunction(atom, arguments);
  context->Exit();

  if (receiveFn->HasException()) {
    std::cout << "ERROR: Exception in JS receiving message "
        << message->GetName().ToString() << "\n";
    return false;
  } else {
    return true;
  }
}
