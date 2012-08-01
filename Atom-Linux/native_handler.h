#ifndef CEF_TESTS_CEFCLIENT_NATIVE_HANDLER_H_
#define CEF_TESTS_CEFCLIENT_NATIVE_HANDLER_H_

#include "include/cef_base.h"
#include "include/cef_v8.h"
#include <string>
#include <map>

struct CallbackContext {
  CefRefPtr<CefV8Context> context;
  CefRefPtr<CefV8Value> function;
  CefRefPtr<CefV8Value> eventTypes;
};

struct NotifyContext {
  int descriptor;
  std::map<int, std::map<std::string, CallbackContext> > callbacks;
};

class NativeHandler: public CefV8Handler {
public:
  NativeHandler();

  CefRefPtr<CefV8Value> object;

  GtkWidget* window;

  std::string path;

  virtual bool Execute(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void NotifyWatchers();

IMPLEMENT_REFCOUNTING(NativeHandler)
  ;

private:

  int notifyFd;

  unsigned long int idCounter;

  std::map<int, std::map<std::string, CallbackContext> > pathCallbacks;

  std::map<std::string, int> pathDescriptors;

  void Exists(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void Read(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void Absolute(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void List(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void AsyncList(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void IsFile(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void IsDirectory(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void OpenDialog(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void Open(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void Write(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void WriteToPasteboard(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void ReadFromPasteboard(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void MakeDirectory(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void Move(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void Remove(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void Alert(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void WatchPath(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);

  void UnwatchPath(const CefString& name, CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
      CefString& exception);
};

#endif
