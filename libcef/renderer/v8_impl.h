// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_RENDERER_V8_IMPL_H_
#define CEF_LIBCEF_RENDERER_V8_IMPL_H_
#pragma once

#include <vector>

#include "include/cef_v8.h"
#include "libcef/renderer/thread_util.h"

#include "v8/include/v8.h"
#include "base/memory/ref_counted.h"

class CefTrackNode;

namespace WebKit {
class WebFrame;
};

// Template for V8 Handle types. This class is used to ensure that V8 objects
// are only released on the UI thread.
template <class v8class>
class CefReleaseV8HandleOnUIThread
    : public base::RefCountedThreadSafe<CefReleaseV8HandleOnUIThread<v8class>,
                                        CefDeleteOnRenderThread> {
 public:
  typedef v8::Handle<v8class> handleType;
  typedef v8::Persistent<v8class> persistentType;
  typedef CefReleaseV8HandleOnUIThread<v8class> superType;

  explicit CefReleaseV8HandleOnUIThread(handleType v) {
    v8_handle_ = persistentType::New(v);
  }
  virtual ~CefReleaseV8HandleOnUIThread() {
  }

  handleType GetHandle() {
    return v8_handle_;
  }

  persistentType v8_handle_;
};

// Special class for a v8::Context to ensure that it is deleted from the UI
// thread.
class CefV8ContextHandle : public CefReleaseV8HandleOnUIThread<v8::Context> {
 public:
  explicit CefV8ContextHandle(handleType context)
    : superType(context) {
  }

  // Context handles are disposed rather than makeweak.
  ~CefV8ContextHandle() {
    v8_handle_.Dispose();
    v8_handle_.Clear();
  }
};

class CefV8ContextImpl : public CefV8Context {
 public:
  explicit CefV8ContextImpl(v8::Handle<v8::Context> context);
  virtual ~CefV8ContextImpl();

  virtual CefRefPtr<CefBrowser> GetBrowser() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetFrame() OVERRIDE;
  virtual CefRefPtr<CefV8Value> GetGlobal() OVERRIDE;
  virtual bool Enter() OVERRIDE;
  virtual bool Exit() OVERRIDE;
  virtual bool IsSame(CefRefPtr<CefV8Context> that) OVERRIDE;
  virtual bool Eval(const CefString& code,
                    CefRefPtr<CefV8Value>& retval,
                    CefRefPtr<CefV8Exception>& exception) OVERRIDE;

  v8::Local<v8::Context> GetContext();
  WebKit::WebFrame* GetWebFrame();

 protected:
  scoped_refptr<CefV8ContextHandle> v8_context_;

#ifndef NDEBUG
  // Used in debug builds to catch missing Exits in destructor.
  int enter_count_;
#endif

  IMPLEMENT_REFCOUNTING(CefV8ContextImpl);
};

// Special class for a v8::Value to ensure that it is deleted from the UI
// thread.
class CefV8ValueHandle: public CefReleaseV8HandleOnUIThread<v8::Value> {
 public:
  CefV8ValueHandle(handleType value, CefTrackNode* tracker)
    : superType(value),
      tracker_(tracker) {
  }
  // Destructor implementation is provided in v8_impl.cc.
  ~CefV8ValueHandle();

  CefTrackNode* GetTracker() {
    return tracker_;
  }

 private:
  // For Object and Function types, we need to hold on to a reference to their
  // internal data or function handler objects that are reference counted.
  CefTrackNode* tracker_;

  DISALLOW_COPY_AND_ASSIGN(CefV8ValueHandle);
};

class CefV8ValueImpl : public CefV8Value {
 public:
  CefV8ValueImpl(v8::Handle<v8::Value> value, CefTrackNode* tracker = NULL);
  virtual ~CefV8ValueImpl();

  virtual bool IsUndefined() OVERRIDE;
  virtual bool IsNull() OVERRIDE;
  virtual bool IsBool() OVERRIDE;
  virtual bool IsInt() OVERRIDE;
  virtual bool IsUInt() OVERRIDE;
  virtual bool IsDouble() OVERRIDE;
  virtual bool IsDate() OVERRIDE;
  virtual bool IsString() OVERRIDE;
  virtual bool IsObject() OVERRIDE;
  virtual bool IsArray() OVERRIDE;
  virtual bool IsFunction() OVERRIDE;
  virtual bool IsSame(CefRefPtr<CefV8Value> value) OVERRIDE;
  virtual bool GetBoolValue() OVERRIDE;
  virtual int32 GetIntValue() OVERRIDE;
  virtual uint32 GetUIntValue() OVERRIDE;
  virtual double GetDoubleValue() OVERRIDE;
  virtual CefTime GetDateValue() OVERRIDE;
  virtual CefString GetStringValue() OVERRIDE;
  virtual bool IsUserCreated() OVERRIDE;
  virtual bool HasException() OVERRIDE;
  virtual CefRefPtr<CefV8Exception> GetException() OVERRIDE;
  virtual bool ClearException() OVERRIDE;
  virtual bool WillRethrowExceptions() OVERRIDE;
  virtual bool SetRethrowExceptions(bool rethrow) OVERRIDE;
  virtual bool HasValue(const CefString& key) OVERRIDE;
  virtual bool HasValue(int index) OVERRIDE;
  virtual bool DeleteValue(const CefString& key) OVERRIDE;
  virtual bool DeleteValue(int index) OVERRIDE;
  virtual CefRefPtr<CefV8Value> GetValue(const CefString& key) OVERRIDE;
  virtual CefRefPtr<CefV8Value> GetValue(int index) OVERRIDE;
  virtual bool SetValue(const CefString& key, CefRefPtr<CefV8Value> value,
                        PropertyAttribute attribute) OVERRIDE;
  virtual bool SetValue(int index, CefRefPtr<CefV8Value> value) OVERRIDE;
  virtual bool SetValue(const CefString& key, AccessControl settings,
                        PropertyAttribute attribute) OVERRIDE;
  virtual bool GetKeys(std::vector<CefString>& keys) OVERRIDE;
  virtual bool SetUserData(CefRefPtr<CefBase> user_data) OVERRIDE;
  virtual CefRefPtr<CefBase> GetUserData() OVERRIDE;
  virtual int GetExternallyAllocatedMemory() OVERRIDE;
  virtual int AdjustExternallyAllocatedMemory(int change_in_bytes) OVERRIDE;
  virtual int GetArrayLength() OVERRIDE;
  virtual CefString GetFunctionName() OVERRIDE;
  virtual CefRefPtr<CefV8Handler> GetFunctionHandler() OVERRIDE;
  virtual CefRefPtr<CefV8Value> ExecuteFunction(
      CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments) OVERRIDE;
  virtual CefRefPtr<CefV8Value> ExecuteFunctionWithContext(
      CefRefPtr<CefV8Context> context,
      CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments) OVERRIDE;

  inline v8::Handle<v8::Value> GetHandle() {
    DCHECK(v8_value_.get());
    return v8_value_->GetHandle();
  }

 protected:
  // Test for and record any exception.
  bool HasCaught(v8::TryCatch& try_catch);

  scoped_refptr<CefV8ValueHandle> v8_value_;
  CefRefPtr<CefV8Exception> last_exception_;
  bool rethrow_exceptions_;

  IMPLEMENT_REFCOUNTING(CefV8ValueImpl);
  DISALLOW_COPY_AND_ASSIGN(CefV8ValueImpl);
};

#endif  // CEF_LIBCEF_RENDERER_V8_IMPL_H_
