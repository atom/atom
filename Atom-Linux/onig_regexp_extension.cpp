#include "onig_regexp_extension.h"
#include "include/cef_base.h"
#include "include/cef_runnable.h"
#include <oniguruma.h>

OnigRegexpExtension::OnigRegexpExtension() :
    CefV8Handler() {

}

bool OnigRegexpExtension::Execute(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {

  return true;
}
