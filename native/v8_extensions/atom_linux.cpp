#include "atom.h"
#include "include/cef_base.h"
#include "include/cef_runnable.h"
#include <iostream>
#include <stdlib.h>
#include "io_utils.h"
#include "message_translation.h"

using namespace std;

namespace v8_extensions {

Atom::Atom() :
    CefV8Handler() {
  string realFilePath = io_utils_real_app_path("/native/v8_extensions/atom.js");
  if (!realFilePath.empty()) {
    string extensionCode;
    if (io_utils_read(realFilePath, &extensionCode) > 0)
      CefRegisterExtension("v8/atom", extensionCode, this);
  }
}

bool Atom::Execute(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  CefRefPtr<CefBrowser> browser =
      CefV8Context::GetCurrentContext()->GetBrowser();

  if (name == "sendMessageToBrowserProcess") {
    if (arguments.size() == 0 || !arguments[0]->IsString()) {
      exception = "You must supply a message name";
      return false;
    }

    CefString name = arguments[0]->GetStringValue();
    CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);

    if (arguments.size() > 1 && arguments[1]->IsArray()) {
      TranslateList(arguments[1], message->GetArgumentList());
    }

    browser->SendProcessMessage(PID_BROWSER, message);
    return true;
  }
  return false;
}
}
