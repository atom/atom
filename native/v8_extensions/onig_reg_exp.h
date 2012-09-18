#import "include/cef_base.h"
#import "include/cef_v8.h"

namespace v8_extensions {

class OnigRegExp : public CefV8Handler {
public:
  OnigRegExp();
    
  virtual bool Execute(const CefString& name,
                       CefRefPtr<CefV8Value> object,
                       const CefV8ValueList& arguments,
                       CefRefPtr<CefV8Value>& retval,
                       CefString& exception) OVERRIDE;
  
  // Provide the reference counting implementation for this class.
  IMPLEMENT_REFCOUNTING(OnigRegExp);
};

}