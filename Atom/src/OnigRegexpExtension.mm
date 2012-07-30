#import "OnigRegexpExtension.h"
#import "include/cef_base.h"
#import "include/cef_v8.h"
#import <Cocoa/Cocoa.h>
#import <iostream>


class OnigRegexpUserData : public CefBase {
public:
  OnigRegexpUserData(CefString source) {
    m_source = source;
  }
  
  CefString m_source;
  
  IMPLEMENT_REFCOUNTING(OnigRegexpUserData);

};


OnigRegexpExtension::OnigRegexpExtension() : CefV8Handler() {  
  NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"src/stdlib/onig-regexp-extension.js"];
  NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  CefRegisterExtension("v8/oniguruma", [extensionCode UTF8String], this);
}

bool OnigRegexpExtension::Execute(const CefString& name,
                            CefRefPtr<CefV8Value> object,
                            const CefV8ValueList& arguments,
                            CefRefPtr<CefV8Value>& retval,
                            CefString& exception) {

  if (name == "buildOnigRegexp") {    
    CefRefPtr<CefBase> userData = new OnigRegexpUserData(arguments[0]->GetStringValue());
    retval = CefV8Value::CreateObject(userData, NULL);
  }
  else if (name == "exec") {
    OnigRegexpUserData *userData = (OnigRegexpUserData *)object->GetUserData().get();
    retval = CefV8Value::CreateString(userData->m_source);
  }
  return true;
}

