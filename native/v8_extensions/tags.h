#include "include/cef_base.h"
#include "include/cef_v8.h"
#include "readtags.h"

namespace v8_extensions {

  class Tags : public CefV8Handler {
  public:
    static void CreateContextBinding(CefRefPtr<CefV8Context> context);
    virtual bool Execute(const CefString& name,
                         CefRefPtr<CefV8Value> object,
                         const CefV8ValueList& arguments,
                         CefRefPtr<CefV8Value>& retval,
                         CefString& exception) OVERRIDE;

    // Provide the reference counting implementation for this class.
    IMPLEMENT_REFCOUNTING(Tags);

  private:
    static CefRefPtr<CefV8Handler> GetInstance();
    Tags();
    Tags(Tags const&);
    void operator=(Tags const&);
    CefRefPtr<CefV8Value> ParseEntry(tagEntry entry);
  };

}
