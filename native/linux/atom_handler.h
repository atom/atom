#ifndef ATOM_HANDLER_H_
#define ATOM_HANDLER_H_

#include "include/cef_base.h"
#include "include/cef_v8.h"

class AtomHandler: public CefV8Handler {

public:
  AtomHandler();

  virtual bool Execute(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

IMPLEMENT_REFCOUNTING(AtomHandler)
  ;

};

#endif
