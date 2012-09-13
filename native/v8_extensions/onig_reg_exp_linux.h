#ifndef ONIG_REG_EXP_LINUX_H_
#define ONIG_REG_EXP_LINUX_H_

#include "include/cef_base.h"
#include "include/cef_v8.h"

namespace v8_extensions {

class OnigRegexpExtension: public CefV8Handler {

public:
  OnigRegexpExtension();

  virtual bool Execute(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

IMPLEMENT_REFCOUNTING(OnigRegexpExtension)
  ;

};

}
#endif
