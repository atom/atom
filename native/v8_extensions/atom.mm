#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#import "atom.h"
#import "atom_application.h"
#import "message_translation.h"

namespace v8_extensions {
  Atom::Atom() : CefV8Handler() {
    NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/atom.js"];
    NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    CefRegisterExtension("v8/atom", [extensionCode UTF8String], this);
  }

  bool Atom::Execute(const CefString& name,
                              CefRefPtr<CefV8Value> object,
                              const CefV8ValueList& arguments,
                              CefRefPtr<CefV8Value>& retval,
                              CefString& exception) {
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
  };
}
