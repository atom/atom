#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#import "atom.h"
#import "atom_application.h"
#import "message_translation.h"

namespace v8_extensions {
  Atom::Atom() : CefV8Handler() {
  }

  void Atom::CreateContextBinding(CefRefPtr<CefV8Context> context) {
    CefRefPtr<CefV8Value> function = CefV8Value::CreateFunction("sendMessageToBrowserProcess", this);
    CefRefPtr<CefV8Value> atomObject = CefV8Value::CreateObject(NULL);
    atomObject->SetValue("sendMessageToBrowserProcess", function, V8_PROPERTY_ATTRIBUTE_NONE);
    CefRefPtr<CefV8Value> global = context->GetGlobal();
    global->SetValue("atom", atomObject, V8_PROPERTY_ATTRIBUTE_NONE);
  }

  bool Atom::Execute(const CefString& name,
                              CefRefPtr<CefV8Value> object,
                              const CefV8ValueList& arguments,
                              CefRefPtr<CefV8Value>& retval,
                              CefString& exception) {
    @autoreleasepool {
      CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();

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
  };
}
