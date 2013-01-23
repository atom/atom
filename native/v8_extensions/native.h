#include "include/cef_base.h"
#include "include/cef_v8.h"


namespace v8_extensions {

class Native : public CefV8Handler {
public:

  static void CreateContextBinding(CefRefPtr<CefV8Context> context);
  virtual bool Execute(const CefString& name,
                                      CefRefPtr<CefV8Value> object,
                                      const CefV8ValueList& arguments,
                                      CefRefPtr<CefV8Value>& retval,
                                      CefString& exception) OVERRIDE;

  // Provide the reference counting implementation for this class.
  IMPLEMENT_REFCOUNTING(Native);

private:
  Native();
  Native(Native const&);
  static CefRefPtr<CefV8Handler> GetInstance();
  void operator=(Native const&);
  std::string windowState;
};

}
