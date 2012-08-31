#ifndef ONIG_REGEXP_EXTENSION_H_
#define ONIG_REGEXP_EXTENSION_H_

#include "include/cef_base.h"
#include "include/cef_v8.h"

class OnigRegexpExtension: public CefV8Handler {

public:
  OnigRegexpExtension();

  virtual bool Execute(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

IMPLEMENT_REFCOUNTING(OnigRegexpExtension)
  ;

};

#endif
