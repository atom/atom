#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#import "atom.h"
#import "atom_application.h"
#import "util.h"


namespace v8_extensions {
  v8_extensions::Atom::Atom() : CefV8Handler() {
    NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/atom.js"];
    NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    CefRegisterExtension("v8/atom", [extensionCode UTF8String], this);
  }
  
  bool v8_extensions::Atom::Execute(const CefString& name,
                              CefRefPtr<CefV8Value> object,
                              const CefV8ValueList& arguments,
                              CefRefPtr<CefV8Value>& retval,
                              CefString& exception) {
    
    CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();
    
    if (name == "open") {
      CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("open");
      CefRefPtr<CefListValue> messageArgs = message->GetArgumentList();      
      messageArgs->SetSize(1);
      messageArgs->SetString(0, arguments[0]->GetStringValue());
      browser->SendProcessMessage(PID_BROWSER, message);
    }
  };
}