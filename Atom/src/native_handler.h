#import "include/cef.h"
#import <Cocoa/Cocoa.h>

class NativeHandler : public CefV8Handler {
public:
  NativeHandler();
  
  CefRefPtr<CefV8Value> m_object;
  
  virtual bool Execute(const CefString& name,
                                      CefRefPtr<CefV8Value> object,
                                      const CefV8ValueList& arguments,
                                      CefRefPtr<CefV8Value>& retval,
                                      CefString& exception) OVERRIDE;
    
  // Provide the reference counting implementation for this class.
  IMPLEMENT_REFCOUNTING(NativeHandler);
};
