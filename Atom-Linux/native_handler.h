#ifndef CEF_TESTS_CEFCLIENT_NATIVE_HANDLER_H_
#define CEF_TESTS_CEFCLIENT_NATIVE_HANDLER_H_

#include "include/cef_base.h"
#include "include/cef_v8.h"

class NativeHandler : public CefV8Handler {
public:
  NativeHandler();
  
  CefRefPtr<CefV8Value> object;
  
  virtual bool Execute(const CefString& name,
                                      CefRefPtr<CefV8Value> object,
                                      const CefV8ValueList& arguments,
                                      CefRefPtr<CefV8Value>& retval,
                                      CefString& exception);
  
  IMPLEMENT_REFCOUNTING(NativeHandler);
};

#endif