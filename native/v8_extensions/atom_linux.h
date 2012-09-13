#ifndef ATOM_LINUX_H_
#define ATOM_LINUX_H_

#include "include/cef_v8.h"

namespace v8_extensions {

class AtomHandler: public CefV8Handler {

public:
  AtomHandler();

  virtual bool Execute(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

IMPLEMENT_REFCOUNTING(AtomHandler)
  ;

};
}

#endif
