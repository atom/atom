// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <string>

#include "base/compiler_specific.h"

#include "third_party/WebKit/Source/WebCore/config.h"
MSVC_PUSH_WARNING_LEVEL(0);
#include "V8Proxy.h"  // NOLINT(build/include)
#include "V8RecursionScope.h"  // NOLINT(build/include)
MSVC_POP_WARNING();
#undef LOG

#include "libcef/renderer/v8_impl.h"

#include "libcef/common/tracker.h"
#include "libcef/renderer/browser_impl.h"
#include "libcef/renderer/thread_util.h"

#include "base/bind.h"
#include "base/lazy_instance.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebKit.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebFrame.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebScriptController.h"

namespace {

static const char kCefTrackObject[] = "Cef::TrackObject";

// Memory manager.

base::LazyInstance<CefTrackManager> g_v8_tracker = LAZY_INSTANCE_INITIALIZER;

class V8TrackObject : public CefTrackNode {
 public:
  V8TrackObject()
      : external_memory_(0) {
  }
  ~V8TrackObject() {
    if (external_memory_ != 0)
      v8::V8::AdjustAmountOfExternalAllocatedMemory(-external_memory_);
  }

  inline int GetExternallyAllocatedMemory() {
    return external_memory_;
  }

  int AdjustExternallyAllocatedMemory(int change_in_bytes) {
    int new_value = external_memory_ + change_in_bytes;
    if (new_value < 0) {
      NOTREACHED() << "External memory usage cannot be less than 0 bytes";
      change_in_bytes = -(external_memory_);
      new_value = 0;
    }

    if (change_in_bytes != 0)
      v8::V8::AdjustAmountOfExternalAllocatedMemory(change_in_bytes);
    external_memory_ = new_value;

    return new_value;
  }

  inline void SetAccessor(CefRefPtr<CefV8Accessor> accessor) {
    accessor_ = accessor;
  }

  inline CefRefPtr<CefV8Accessor> GetAccessor() {
    return accessor_;
  }

  inline void SetHandler(CefRefPtr<CefV8Handler> handler) {
    handler_ = handler;
  }

  inline CefRefPtr<CefV8Handler> GetHandler() {
    return handler_;
  }

  inline void SetUserData(CefRefPtr<CefBase> user_data) {
    user_data_ = user_data;
  }

  inline CefRefPtr<CefBase> GetUserData() {
    return user_data_;
  }

  // Attach this track object to the specified V8 object.
  void AttachTo(v8::Handle<v8::Object> object) {
    object->SetHiddenValue(v8::String::New(kCefTrackObject),
                           v8::External::Wrap(this));
  }

  // Retrieve the track object for the specified V8 object.
  static V8TrackObject* Unwrap(v8::Handle<v8::Object> object) {
    v8::Local<v8::Value> value =
        object->GetHiddenValue(v8::String::New(kCefTrackObject));
    if (!value.IsEmpty())
      return static_cast<V8TrackObject*>(v8::External::Unwrap(value));

    return NULL;
  }

 private:
  CefRefPtr<CefV8Accessor> accessor_;
  CefRefPtr<CefV8Handler> handler_;
  CefRefPtr<CefBase> user_data_;
  int external_memory_;
};

class V8TrackString : public CefTrackNode {
 public:
  explicit V8TrackString(const std::string& str) : string_(str) {}
  const char* GetString() { return string_.c_str(); }

 private:
  std::string string_;
};

void TrackAdd(CefTrackNode* object) {
  g_v8_tracker.Pointer()->Add(object);
}

void TrackDelete(CefTrackNode* object) {
  g_v8_tracker.Pointer()->Delete(object);
}

// Callback for weak persistent reference destruction.
void TrackDestructor(v8::Persistent<v8::Value> object, void* parameter) {
  if (parameter)
    TrackDelete(static_cast<CefTrackNode*>(parameter));

  object.Dispose();
  object.Clear();
}

// Convert a CefString to a V8::String.
v8::Handle<v8::String> GetV8String(const CefString& str) {
#if defined(CEF_STRING_TYPE_UTF16)
  // Already a UTF16 string.
  return v8::String::New(
      reinterpret_cast<uint16_t*>(
          const_cast<CefString::char_type*>(str.c_str())),
      str.length());
#elif defined(CEF_STRING_TYPE_UTF8)
  // Already a UTF8 string.
  return v8::String::New(const_cast<char*>(str.c_str()), str.length());
#else
  // Convert the string to UTF8.
  std::string tmpStr = str;
  return v8::String::New(tmpStr.c_str(), tmpStr.length());
#endif
}

#if defined(CEF_STRING_TYPE_UTF16)
void v8impl_string_dtor(char16* str) {
    delete [] str;
}
#elif defined(CEF_STRING_TYPE_UTF8)
void v8impl_string_dtor(char* str) {
    delete [] str;
}
#endif

// Convert a v8::String to CefString.
void GetCefString(v8::Handle<v8::String> str, CefString& out) {
#if defined(CEF_STRING_TYPE_WIDE)
  // Allocate enough space for a worst-case conversion.
  int len = str->Utf8Length();
  if (len == 0)
    return;
  char* buf = new char[len + 1];
  str->WriteUtf8(buf, len + 1);

  // Perform conversion to the wide type.
  cef_string_t* retws = out.GetWritableStruct();
  cef_string_utf8_to_wide(buf, len, retws);

  delete [] buf;
#else  // !defined(CEF_STRING_TYPE_WIDE)
#if defined(CEF_STRING_TYPE_UTF16)
  int len = str->Length();
  if (len == 0)
    return;
  char16* buf = new char16[len + 1];
  str->Write(reinterpret_cast<uint16_t*>(buf), 0, len + 1);
#else
  // Allocate enough space for a worst-case conversion.
  int len = str->Utf8Length();
  if (len == 0)
    return;
  char* buf = new char[len + 1];
  str->WriteUtf8(buf, len + 1);
#endif

  // Don't perform an extra string copy.
  out.clear();
  cef_string_t* retws = out.GetWritableStruct();
  retws->str = buf;
  retws->length = len;
  retws->dtor = v8impl_string_dtor;
#endif  // !defined(CEF_STRING_TYPE_WIDE)
}

// V8 function callback.
v8::Handle<v8::Value> FunctionCallbackImpl(const v8::Arguments& args) {
  v8::HandleScope handle_scope;

  CefV8Handler* handler =
      static_cast<CefV8Handler*>(v8::External::Unwrap(args.Data()));

  CefV8ValueList params;
  for (int i = 0; i < args.Length(); i++)
    params.push_back(new CefV8ValueImpl(args[i]));

  CefString func_name;
  GetCefString(v8::Handle<v8::String>::Cast(args.Callee()->GetName()),
               func_name);
  CefRefPtr<CefV8Value> object = new CefV8ValueImpl(args.This());
  CefRefPtr<CefV8Value> retval;
  CefString exception;

  if (handler->Execute(func_name, object, params, retval, exception)) {
    if (!exception.empty()) {
      return v8::ThrowException(v8::Exception::Error(GetV8String(exception)));
    } else {
      CefV8ValueImpl* rv = static_cast<CefV8ValueImpl*>(retval.get());
      if (rv)
        return rv->GetHandle();
    }
  }

  return v8::Undefined();
}

// V8 Accessor callbacks
v8::Handle<v8::Value> AccessorGetterCallbackImpl(v8::Local<v8::String> property,
                                                 const v8::AccessorInfo& info) {
  v8::HandleScope handle_scope;

  v8::Handle<v8::Object> obj = info.This();

  CefRefPtr<CefV8Accessor> accessorPtr;

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker)
    accessorPtr = tracker->GetAccessor();

  if (accessorPtr.get()) {
    CefRefPtr<CefV8Value> retval;
    CefRefPtr<CefV8Value> object = new CefV8ValueImpl(obj);
    CefString name, exception;
    GetCefString(property, name);
    if (accessorPtr->Get(name, object, retval, exception)) {
      if (!exception.empty()) {
          return v8::ThrowException(
              v8::Exception::Error(GetV8String(exception)));
      } else {
          CefV8ValueImpl* rv = static_cast<CefV8ValueImpl*>(retval.get());
          if (rv)
            return rv->GetHandle();
      }
    }
  }

  return v8::Undefined();
}

void AccessorSetterCallbackImpl(v8::Local<v8::String> property,
                                v8::Local<v8::Value> value,
                                const v8::AccessorInfo& info) {
  v8::HandleScope handle_scope;

  v8::Handle<v8::Object> obj = info.This();

  CefRefPtr<CefV8Accessor> accessorPtr;

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker)
    accessorPtr = tracker->GetAccessor();

  if (accessorPtr.get()) {
    CefRefPtr<CefV8Value> object = new CefV8ValueImpl(obj);
    CefRefPtr<CefV8Value> cefValue = new CefV8ValueImpl(value);
    CefString name, exception;
    GetCefString(property, name);
    accessorPtr->Set(name, object, cefValue, exception);
    if (!exception.empty()) {
      v8::ThrowException(v8::Exception::Error(GetV8String(exception)));
      return;
    }
  }
}

// V8 extension registration.

class ExtensionWrapper : public v8::Extension {
 public:
  ExtensionWrapper(const char* extension_name,
                   const char* javascript_code,
                   CefV8Handler* handler)
    : v8::Extension(extension_name, javascript_code), handler_(handler) {
    if (handler) {
      // The reference will be released when the process exits.
      V8TrackObject* object = new V8TrackObject;
      object->SetHandler(handler);
      TrackAdd(object);
    }
  }

  virtual v8::Handle<v8::FunctionTemplate> GetNativeFunction(
    v8::Handle<v8::String> name) {
    if (!handler_)
      return v8::Handle<v8::FunctionTemplate>();

    return v8::FunctionTemplate::New(FunctionCallbackImpl,
                                     v8::External::Wrap(handler_));
  }

 private:
  CefV8Handler* handler_;
};

class CefV8ExceptionImpl : public CefV8Exception {
 public:
  explicit CefV8ExceptionImpl(v8::Handle<v8::Message> message)
    : line_number_(0),
      start_position_(0),
      end_position_(0),
      start_column_(0),
      end_column_(0) {
    if (message.IsEmpty())
      return;

    GetCefString(message->Get(), message_);
    GetCefString(message->GetSourceLine(), source_line_);

    if (!message->GetScriptResourceName().IsEmpty())
      GetCefString(message->GetScriptResourceName()->ToString(), script_);

    line_number_ = message->GetLineNumber();
    start_position_ = message->GetStartPosition();
    end_position_ = message->GetEndPosition();
    start_column_ = message->GetStartColumn();
    end_column_ = message->GetEndColumn();
  }

  virtual CefString GetMessage() OVERRIDE { return message_; }
  virtual CefString GetSourceLine() OVERRIDE { return source_line_; }
  virtual CefString GetScriptResourceName() OVERRIDE { return script_; }
  virtual int GetLineNumber() OVERRIDE { return line_number_; }
  virtual int GetStartPosition() OVERRIDE { return start_position_; }
  virtual int GetEndPosition() OVERRIDE { return end_position_; }
  virtual int GetStartColumn() OVERRIDE { return start_column_; }
  virtual int GetEndColumn() OVERRIDE { return end_column_; }

 protected:
  CefString message_;
  CefString source_line_;
  CefString script_;
  int line_number_;
  int start_position_;
  int end_position_;
  int start_column_;
  int end_column_;

  IMPLEMENT_REFCOUNTING(CefV8ExceptionImpl);
};

}  // namespace


// Global functions.

bool CefRegisterExtension(const CefString& extension_name,
                          const CefString& javascript_code,
                          CefRefPtr<CefV8Handler> handler) {
  // Verify that this method was called on the correct thread.
  CEF_REQUIRE_RT_RETURN(false);

  V8TrackString* name = new V8TrackString(extension_name);
  TrackAdd(name);
  V8TrackString* code = new V8TrackString(javascript_code);
  TrackAdd(code);

  ExtensionWrapper* wrapper = new ExtensionWrapper(name->GetString(),
      code->GetString(), handler.get());

  content::RenderThread::Get()->RegisterExtension(wrapper);
  return true;
}


// CefV8Context implementation.

// static
CefRefPtr<CefV8Context> CefV8Context::GetCurrentContext() {
  CefRefPtr<CefV8Context> context;
  CEF_REQUIRE_RT_RETURN(context);
  if (v8::Context::InContext()) {
    v8::HandleScope handle_scope;
    context = new CefV8ContextImpl(v8::Context::GetCurrent());
  }
  return context;
}

// static
CefRefPtr<CefV8Context> CefV8Context::GetEnteredContext() {
  CefRefPtr<CefV8Context> context;
  CEF_REQUIRE_RT_RETURN(context);
  if (v8::Context::InContext()) {
    v8::HandleScope handle_scope;
    context = new CefV8ContextImpl(v8::Context::GetEntered());
  }
  return context;
}

// static
bool CefV8Context::InContext() {
  CEF_REQUIRE_RT_RETURN(false);
  return v8::Context::InContext();
}


// CefV8ContextImpl implementation.

#define CEF_V8_REQUIRE_OBJECT_RETURN(ret) \
  if (!GetHandle()->IsObject()) { \
    NOTREACHED() << "V8 value is not an object"; \
    return ret; \
  }

#define CEF_V8_REQUIRE_ARRAY_RETURN(ret) \
  if (!GetHandle()->IsArray()) { \
    NOTREACHED() << "V8 value is not an array"; \
    return ret; \
  }

#define CEF_V8_REQUIRE_FUNCTION_RETURN(ret) \
  if (!GetHandle()->IsFunction()) { \
    NOTREACHED() << "V8 value is not a function"; \
    return ret; \
  }

CefV8ContextImpl::CefV8ContextImpl(v8::Handle<v8::Context> context)
#ifndef NDEBUG
  : enter_count_(0)
#endif
{  // NOLINT(whitespace/braces)
  v8_context_ = new CefV8ContextHandle(context);
}

CefV8ContextImpl::~CefV8ContextImpl() {
  DLOG_ASSERT(0 == enter_count_);
}

CefRefPtr<CefBrowser> CefV8ContextImpl::GetBrowser() {
  CefRefPtr<CefBrowser> browser;
  CEF_REQUIRE_RT_RETURN(browser);

  WebKit::WebFrame* webframe = GetWebFrame();
  if (webframe)
    browser = CefBrowserImpl::GetBrowserForMainFrame(webframe->top());

  return browser;
}

CefRefPtr<CefFrame> CefV8ContextImpl::GetFrame() {
  CefRefPtr<CefFrame> frame;
  CEF_REQUIRE_RT_RETURN(frame);

  WebKit::WebFrame* webframe = GetWebFrame();
  if (webframe) {
    CefRefPtr<CefBrowserImpl> browser =
        CefBrowserImpl::GetBrowserForMainFrame(webframe->top());
    frame = browser->GetFrame(webframe->identifier());
  }

  return frame;
}

CefRefPtr<CefV8Value> CefV8ContextImpl::GetGlobal() {
  CEF_REQUIRE_RT_RETURN(NULL);

  v8::HandleScope handle_scope;
  v8::Context::Scope context_scope(v8_context_->GetHandle());
  return new CefV8ValueImpl(v8_context_->GetHandle()->Global());
}

bool CefV8ContextImpl::Enter() {
  CEF_REQUIRE_RT_RETURN(false);
  v8_context_->GetHandle()->Enter();
#ifndef NDEBUG
  ++enter_count_;
#endif
  return true;
}

bool CefV8ContextImpl::Exit() {
  CEF_REQUIRE_RT_RETURN(false);
  DLOG_ASSERT(enter_count_ > 0);
  v8_context_->GetHandle()->Exit();
#ifndef NDEBUG
  --enter_count_;
#endif
  return true;
}

bool CefV8ContextImpl::IsSame(CefRefPtr<CefV8Context> that) {
  CEF_REQUIRE_RT_RETURN(false);

  v8::HandleScope handle_scope;

  v8::Local<v8::Context> thatHandle;
  v8::Local<v8::Context> thisHandle = GetContext();

  CefV8ContextImpl* impl = static_cast<CefV8ContextImpl*>(that.get());
  if (impl)
    thatHandle = impl->GetContext();

  return (thisHandle == thatHandle);
}

bool CefV8ContextImpl::Eval(const CefString& code,
                            CefRefPtr<CefV8Value>& retval,
                            CefRefPtr<CefV8Exception>& exception) {
  CEF_REQUIRE_RT_RETURN(NULL);

  if (code.empty()) {
    NOTREACHED() << "invalid input parameter";
    return false;
  }

  v8::HandleScope handle_scope;
  v8::Context::Scope context_scope(v8_context_->GetHandle());
  v8::Local<v8::Object> obj = v8_context_->GetHandle()->Global();

  // Retrieve the eval function.
  v8::Local<v8::Value> val = obj->Get(v8::String::New("eval"));
  if (val.IsEmpty() || !val->IsFunction())
    return false;

  v8::Local<v8::Function> func = v8::Local<v8::Function>::Cast(val);
  v8::Handle<v8::Value> code_val = GetV8String(code);

  v8::TryCatch try_catch;
  try_catch.SetVerbose(true);
  v8::Local<v8::Value> func_rv;

  retval = NULL;
  exception = NULL;

  // Execute the function call using the V8Proxy so that inspector
  // instrumentation works.
  WebCore::V8Proxy* proxy = WebCore::V8Proxy::retrieve();
  DCHECK(proxy);
  if (proxy)
    func_rv = proxy->callFunction(func, obj, 1, &code_val);

  if (try_catch.HasCaught()) {
    exception = new CefV8ExceptionImpl(try_catch.Message());
    return false;
  } else if (!func_rv.IsEmpty()) {
    retval = new CefV8ValueImpl(func_rv);
  }
  return true;
}

v8::Local<v8::Context> CefV8ContextImpl::GetContext() {
  return v8::Local<v8::Context>::New(v8_context_->GetHandle());
}

WebKit::WebFrame* CefV8ContextImpl::GetWebFrame() {
  v8::HandleScope handle_scope;
  v8::Context::Scope context_scope(v8_context_->GetHandle());
  WebKit::WebFrame* frame = WebKit::WebFrame::frameForCurrentContext();
  return frame;
}


// CefV8ValueHandle

// Custom destructor for a v8 value handle which gets called only on the UI
// thread.
CefV8ValueHandle::~CefV8ValueHandle() {
  if (tracker_) {
    TrackAdd(tracker_);
    v8_handle_.MakeWeak(tracker_, TrackDestructor);
  } else {
    v8_handle_.Dispose();
    v8_handle_.Clear();
  }
  tracker_ = NULL;
}


// CefV8Value

// static
CefRefPtr<CefV8Value> CefV8Value::CreateUndefined() {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  return new CefV8ValueImpl(v8::Undefined());
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateNull() {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  return new CefV8ValueImpl(v8::Null());
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateBool(bool value) {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  return new CefV8ValueImpl(v8::Boolean::New(value));
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateInt(int32 value) {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  return new CefV8ValueImpl(v8::Int32::New(value));
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateUInt(uint32 value) {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  return new CefV8ValueImpl(v8::Int32::NewFromUnsigned(value));
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateDouble(double value) {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  return new CefV8ValueImpl(v8::Number::New(value));
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateDate(const CefTime& date) {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  // Convert from seconds to milliseconds.
  return new CefV8ValueImpl(v8::Date::New(date.GetDoubleT() * 1000));
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateString(const CefString& value) {
  CEF_REQUIRE_RT_RETURN(NULL);
  v8::HandleScope handle_scope;
  return new CefV8ValueImpl(GetV8String(value));
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateObject(
    CefRefPtr<CefV8Accessor> accessor) {
  CEF_REQUIRE_RT_RETURN(NULL);

  v8::HandleScope handle_scope;

  v8::Local<v8::Context> context = v8::Context::GetCurrent();
  if (context.IsEmpty()) {
    NOTREACHED() << "not currently in a V8 context";
    return NULL;
  }

  // Create the new V8 object.
  v8::Local<v8::Object> obj = v8::Object::New();

  // Create a tracker object that will cause the user data and/or accessor
  // reference to be released when the V8 object is destroyed.
  V8TrackObject* tracker = new V8TrackObject;
  tracker->SetAccessor(accessor);

  // Attach the tracker object.
  tracker->AttachTo(obj);

  return new CefV8ValueImpl(obj, tracker);
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateArray(int length) {
  CEF_REQUIRE_RT_RETURN(NULL);

  v8::HandleScope handle_scope;

  v8::Local<v8::Context> context = v8::Context::GetCurrent();
  if (context.IsEmpty()) {
    NOTREACHED() << "not currently in a V8 context";
    return NULL;
  }

  // Create a tracker object that will cause the user data reference to be
  // released when the V8 object is destroyed.
  V8TrackObject* tracker = new V8TrackObject;

  // Create the new V8 array.
  v8::Local<v8::Array> arr = v8::Array::New(length);

  // Attach the tracker object.
  tracker->AttachTo(arr);

  return new CefV8ValueImpl(arr, tracker);
}

// static
CefRefPtr<CefV8Value> CefV8Value::CreateFunction(
    const CefString& name,
    CefRefPtr<CefV8Handler> handler) {
  CEF_REQUIRE_RT_RETURN(NULL);

  if (!handler.get()) {
    NOTREACHED() << "invalid parameter";
    return NULL;
  }

  v8::HandleScope handle_scope;

  v8::Local<v8::Context> context = v8::Context::GetCurrent();
  if (context.IsEmpty()) {
    NOTREACHED() << "not currently in a V8 context";
    return NULL;
  }

  // Create a new V8 function template.
  v8::Local<v8::FunctionTemplate> tmpl = v8::FunctionTemplate::New();

  v8::Local<v8::Value> data = v8::External::Wrap(handler.get());

  // Set the function handler callback.
  tmpl->SetCallHandler(FunctionCallbackImpl, data);

  // Retrieve the function object and set the name.
  v8::Local<v8::Function> func = tmpl->GetFunction();
  if (func.IsEmpty()) {
    NOTREACHED() << "failed to create V8 function";
    return NULL;
  }

  func->SetName(GetV8String(name));

  // Create a tracker object that will cause the user data and/or handler
  // reference to be released when the V8 object is destroyed.
  V8TrackObject* tracker = new V8TrackObject;
  tracker->SetHandler(handler);

  // Attach the tracker object.
  tracker->AttachTo(func);

  // Create the CefV8ValueImpl and provide a tracker object that will cause
  // the handler reference to be released when the V8 object is destroyed.
  return new CefV8ValueImpl(func, tracker);
}


// CefV8ValueImpl

CefV8ValueImpl::CefV8ValueImpl(v8::Handle<v8::Value> value,
                               CefTrackNode* tracker)
    : rethrow_exceptions_(false) {
  v8_value_ = new CefV8ValueHandle(value, tracker);
}

CefV8ValueImpl::~CefV8ValueImpl() {
}

bool CefV8ValueImpl::IsUndefined() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsUndefined();
}

bool CefV8ValueImpl::IsNull() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsNull();
}

bool CefV8ValueImpl::IsBool() {
  CEF_REQUIRE_RT_RETURN(false);
  return (GetHandle()->IsBoolean() || GetHandle()->IsTrue()
             || GetHandle()->IsFalse());
}

bool CefV8ValueImpl::IsInt() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsInt32();
}

bool CefV8ValueImpl::IsUInt() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsUint32();
}

bool CefV8ValueImpl::IsDouble() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsNumber();
}

bool CefV8ValueImpl::IsDate() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsDate();
}

bool CefV8ValueImpl::IsString() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsString();
}

bool CefV8ValueImpl::IsObject() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsObject();
}

bool CefV8ValueImpl::IsArray() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsArray();
}

bool CefV8ValueImpl::IsFunction() {
  CEF_REQUIRE_RT_RETURN(false);
  return GetHandle()->IsFunction();
}

bool CefV8ValueImpl::IsSame(CefRefPtr<CefV8Value> that) {
  CEF_REQUIRE_RT_RETURN(false);

  v8::HandleScope handle_scope;

  v8::Handle<v8::Value> thatHandle;
  v8::Handle<v8::Value> thisHandle = GetHandle();

  CefV8ValueImpl* impl = static_cast<CefV8ValueImpl*>(that.get());
  if (impl)
    thatHandle = impl->GetHandle();

  return (thisHandle == thatHandle);
}

bool CefV8ValueImpl::GetBoolValue() {
  CEF_REQUIRE_RT_RETURN(false);
  if (GetHandle()->IsTrue()) {
    return true;
  } else if (GetHandle()->IsFalse()) {
    return false;
  } else {
    v8::HandleScope handle_scope;
    v8::Local<v8::Boolean> val = GetHandle()->ToBoolean();
    return val->Value();
  }
}

int32 CefV8ValueImpl::GetIntValue() {
  CEF_REQUIRE_RT_RETURN(0);
  v8::HandleScope handle_scope;
  v8::Local<v8::Int32> val = GetHandle()->ToInt32();
  return val->Value();
}

uint32 CefV8ValueImpl::GetUIntValue() {
  CEF_REQUIRE_RT_RETURN(0);
  v8::HandleScope handle_scope;
  v8::Local<v8::Uint32> val = GetHandle()->ToUint32();
  return val->Value();
}

double CefV8ValueImpl::GetDoubleValue() {
  CEF_REQUIRE_RT_RETURN(0.);
  v8::HandleScope handle_scope;
  v8::Local<v8::Number> val = GetHandle()->ToNumber();
  return val->Value();
}

CefTime CefV8ValueImpl::GetDateValue() {
  CEF_REQUIRE_RT_RETURN(CefTime(0.));
  v8::HandleScope handle_scope;
  v8::Local<v8::Number> val = GetHandle()->ToNumber();
  // Convert from milliseconds to seconds.
  return CefTime(val->Value() / 1000);
}

CefString CefV8ValueImpl::GetStringValue() {
  CefString rv;
  CEF_REQUIRE_RT_RETURN(rv);
  v8::HandleScope handle_scope;
  GetCefString(GetHandle()->ToString(), rv);
  return rv;
}

bool CefV8ValueImpl::IsUserCreated() {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  return (tracker != NULL);
}

bool CefV8ValueImpl::HasException() {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  return (last_exception_.get() != NULL);
}

CefRefPtr<CefV8Exception> CefV8ValueImpl::GetException() {
  CEF_REQUIRE_RT_RETURN(NULL);
  CEF_V8_REQUIRE_OBJECT_RETURN(NULL);

  return last_exception_;
}

bool CefV8ValueImpl::ClearException() {
  CEF_REQUIRE_RT_RETURN(NULL);
  CEF_V8_REQUIRE_OBJECT_RETURN(NULL);

  last_exception_ = NULL;
  return true;
}

bool CefV8ValueImpl::WillRethrowExceptions() {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  return rethrow_exceptions_;
}

bool CefV8ValueImpl::SetRethrowExceptions(bool rethrow) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  rethrow_exceptions_ = rethrow;
  return true;
}

bool CefV8ValueImpl::HasValue(const CefString& key) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  if (key.empty()) {
    NOTREACHED() << "invalid input parameter";
    return false;
  }

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();
  return obj->Has(GetV8String(key));
}

bool CefV8ValueImpl::HasValue(int index) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  if (index < 0) {
    NOTREACHED() << "invalid input parameter";
    return false;
  }

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();
  return obj->Has(index);
}

bool CefV8ValueImpl::DeleteValue(const CefString& key) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  if (key.empty()) {
    NOTREACHED() << "invalid input parameter";
    return false;
  }

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  v8::TryCatch try_catch;
  try_catch.SetVerbose(true);
  bool del = obj->Delete(GetV8String(key));
  return (!HasCaught(try_catch) && del);
}

bool CefV8ValueImpl::DeleteValue(int index) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  if (index < 0) {
    NOTREACHED() << "invalid input parameter";
    return false;
  }

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  v8::TryCatch try_catch;
  try_catch.SetVerbose(true);
  bool del = obj->Delete(index);
  return (!HasCaught(try_catch) && del);
}

CefRefPtr<CefV8Value> CefV8ValueImpl::GetValue(const CefString& key) {
  CEF_REQUIRE_RT_RETURN(NULL);
  CEF_V8_REQUIRE_OBJECT_RETURN(NULL);

  if (key.empty()) {
    NOTREACHED() << "invalid input parameter";
    return NULL;
  }

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  v8::TryCatch try_catch;
  try_catch.SetVerbose(true);
  v8::Local<v8::Value> value = obj->Get(GetV8String(key));
  if (!HasCaught(try_catch) && !value.IsEmpty())
    return new CefV8ValueImpl(value);
  return NULL;
}

CefRefPtr<CefV8Value> CefV8ValueImpl::GetValue(int index) {
  CEF_REQUIRE_RT_RETURN(NULL);
  CEF_V8_REQUIRE_OBJECT_RETURN(NULL);

  if (index < 0) {
    NOTREACHED() << "invalid input parameter";
    return NULL;
  }

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  v8::TryCatch try_catch;
  try_catch.SetVerbose(true);
  v8::Local<v8::Value> value = obj->Get(v8::Number::New(index));
  if (!HasCaught(try_catch) && !value.IsEmpty())
    return new CefV8ValueImpl(value);
  return NULL;
}

bool CefV8ValueImpl::SetValue(const CefString& key,
                              CefRefPtr<CefV8Value> value,
                              PropertyAttribute attribute) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  CefV8ValueImpl* impl = static_cast<CefV8ValueImpl*>(value.get());
  if (impl && !key.empty()) {
    v8::HandleScope handle_scope;
    v8::Local<v8::Object> obj = GetHandle()->ToObject();

    v8::TryCatch try_catch;
    try_catch.SetVerbose(true);
    bool set = obj->Set(GetV8String(key), impl->GetHandle(),
                        static_cast<v8::PropertyAttribute>(attribute));
    return (!HasCaught(try_catch) && set);
  } else {
    NOTREACHED() << "invalid input parameter";
    return false;
  }
}

bool CefV8ValueImpl::SetValue(int index, CefRefPtr<CefV8Value> value) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  if (index < 0) {
    NOTREACHED() << "invalid input parameter";
    return false;
  }

  CefV8ValueImpl* impl = static_cast<CefV8ValueImpl*>(value.get());
  if (impl) {
    v8::HandleScope handle_scope;
    v8::Local<v8::Object> obj = GetHandle()->ToObject();

    v8::TryCatch try_catch;
    try_catch.SetVerbose(true);
    bool set = obj->Set(index, impl->GetHandle());
    return (!HasCaught(try_catch) && set);
  } else {
    NOTREACHED() << "invalid input parameter";
    return false;
  }
}

bool CefV8ValueImpl::SetValue(const CefString& key, AccessControl settings,
                              PropertyAttribute attribute) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  if (key.empty()) {
    NOTREACHED() << "invalid input parameter";
    return false;
  }

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  CefRefPtr<CefV8Accessor> accessorPtr;

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker)
    accessorPtr = tracker->GetAccessor();

  // Verify that an accessor exists for this object.
  if (!accessorPtr.get())
    return false;

  v8::AccessorGetter getter = AccessorGetterCallbackImpl;
  v8::AccessorSetter setter = (attribute & V8_PROPERTY_ATTRIBUTE_READONLY) ?
      NULL : AccessorSetterCallbackImpl;

  v8::TryCatch try_catch;
  try_catch.SetVerbose(true);
  bool set = obj->SetAccessor(GetV8String(key), getter, setter, obj,
                              static_cast<v8::AccessControl>(settings),
                              static_cast<v8::PropertyAttribute>(attribute));
  return (!HasCaught(try_catch) && set);
}

bool CefV8ValueImpl::GetKeys(std::vector<CefString>& keys) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();
  v8::Local<v8::Array> arr_keys = obj->GetPropertyNames();
  uint32_t len = arr_keys->Length();
  for (uint32_t i = 0; i < len; ++i) {
    v8::Local<v8::Value> value = arr_keys->Get(v8::Integer::New(i));
    CefString str;
    GetCefString(value->ToString(), str);
    keys.push_back(str);
  }
  return true;
}

bool CefV8ValueImpl::SetUserData(CefRefPtr<CefBase> user_data) {
  CEF_REQUIRE_RT_RETURN(false);
  CEF_V8_REQUIRE_OBJECT_RETURN(false);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker) {
    tracker->SetUserData(user_data);
    return true;
  }

  return false;
}

CefRefPtr<CefBase> CefV8ValueImpl::GetUserData() {
  CEF_REQUIRE_RT_RETURN(NULL);
  CEF_V8_REQUIRE_OBJECT_RETURN(NULL);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker)
    return tracker->GetUserData();

  return NULL;
}

int CefV8ValueImpl::GetExternallyAllocatedMemory() {
  CEF_REQUIRE_RT_RETURN(0);
  CEF_V8_REQUIRE_OBJECT_RETURN(0);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker)
    return tracker->GetExternallyAllocatedMemory();

  return 0;
}

int CefV8ValueImpl::AdjustExternallyAllocatedMemory(int change_in_bytes) {
  CEF_REQUIRE_RT_RETURN(0);
  CEF_V8_REQUIRE_OBJECT_RETURN(0);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker)
    return tracker->AdjustExternallyAllocatedMemory(change_in_bytes);

  return 0;
}

int CefV8ValueImpl::GetArrayLength() {
  CEF_REQUIRE_RT_RETURN(0);
  CEF_V8_REQUIRE_ARRAY_RETURN(0);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();
  v8::Local<v8::Array> arr = v8::Local<v8::Array>::Cast(obj);
  return arr->Length();
}

CefString CefV8ValueImpl::GetFunctionName() {
  CefString rv;
  CEF_REQUIRE_RT_RETURN(rv);
  CEF_V8_REQUIRE_FUNCTION_RETURN(rv);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();
  v8::Local<v8::Function> func = v8::Local<v8::Function>::Cast(obj);
  GetCefString(v8::Handle<v8::String>::Cast(func->GetName()), rv);
  return rv;
}

CefRefPtr<CefV8Handler> CefV8ValueImpl::GetFunctionHandler() {
  CEF_REQUIRE_RT_RETURN(NULL);
  CEF_V8_REQUIRE_FUNCTION_RETURN(NULL);

  v8::HandleScope handle_scope;
  v8::Local<v8::Object> obj = GetHandle()->ToObject();

  V8TrackObject* tracker = V8TrackObject::Unwrap(obj);
  if (tracker)
    return tracker->GetHandler();

  return NULL;
}

CefRefPtr<CefV8Value> CefV8ValueImpl::ExecuteFunction(
      CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments) {
  // An empty context value defaults to the current context.
  CefRefPtr<CefV8Context> context;
  return ExecuteFunctionWithContext(context, object, arguments);
}

CefRefPtr<CefV8Value> CefV8ValueImpl::ExecuteFunctionWithContext(
      CefRefPtr<CefV8Context> context,
      CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments)  {
  CEF_REQUIRE_RT_RETURN(NULL);
  CEF_V8_REQUIRE_FUNCTION_RETURN(NULL);

  v8::HandleScope handle_scope;

  v8::Local<v8::Context> context_local;
  if (context.get()) {
    CefV8ContextImpl* context_impl =
        static_cast<CefV8ContextImpl*>(context.get());
    context_local = context_impl->GetContext();
  } else {
    context_local = v8::Context::GetCurrent();
  }

  v8::Context::Scope context_scope(context_local);

  v8::Local<v8::Object> obj = GetHandle()->ToObject();
  v8::Local<v8::Function> func = v8::Local<v8::Function>::Cast(obj);
  v8::Handle<v8::Object> recv;

  // Default to the global object if no object or a non-object was provided.
  if (object.get() && object->IsObject()) {
    CefV8ValueImpl* recv_impl = static_cast<CefV8ValueImpl*>(object.get());
    recv = v8::Handle<v8::Object>::Cast(recv_impl->GetHandle());
  } else {
    recv = context_local->Global();
  }

  int argc = arguments.size();
  v8::Handle<v8::Value> *argv = NULL;
  if (argc > 0) {
    argv = new v8::Handle<v8::Value>[argc];
    for (int i = 0; i < argc; ++i)
      argv[i] = static_cast<CefV8ValueImpl*>(arguments[i].get())->GetHandle();
  }

  CefRefPtr<CefV8Value> retval;

  {
    v8::TryCatch try_catch;
    try_catch.SetVerbose(true);
    v8::Local<v8::Value> func_rv;

    // Execute the function call using the V8Proxy so that inspector
    // instrumentation works.
    WebCore::V8Proxy* proxy = WebCore::V8Proxy::retrieve();
    DCHECK(proxy);
    if (proxy)
      func_rv = proxy->callFunction(func, recv, argc, argv);

    if (!HasCaught(try_catch) && !func_rv.IsEmpty())
      retval = new CefV8ValueImpl(func_rv);
  }

  if (argv)
    delete [] argv;

  return retval;
}

bool CefV8ValueImpl::HasCaught(v8::TryCatch& try_catch) {
  if (try_catch.HasCaught()) {
    last_exception_ = new CefV8ExceptionImpl(try_catch.Message());
    if (rethrow_exceptions_)
      try_catch.ReThrow();
    return true;
  } else {
    if (last_exception_.get())
      last_exception_ = NULL;
    return false;
  }
}
