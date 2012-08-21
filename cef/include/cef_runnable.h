// Copyright (c) 2012 Marshall A. Greenblatt. Portions Copyright (c)
// 2006-2011 Google Inc. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// The contents of this file are a modified extract of base/task.h

#ifndef CEF_INCLUDE_CEF_RUNNABLE_H_
#define CEF_INCLUDE_CEF_RUNNABLE_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_task.h"
#ifdef BUILDING_CEF_SHARED
#include "base/tuple.h"
#else
#include "internal/cef_tuple.h"
#endif

// CefRunnableMethodTraits -----------------------------------------------------
//
// This traits-class is used by CefRunnableMethod to manage the lifetime of the
// callee object.  By default, it is assumed that the callee supports AddRef
// and Release methods.  A particular class can specialize this template to
// define other lifetime management.  For example, if the callee is known to
// live longer than the CefRunnableMethod object, then a CefRunnableMethodTraits
// struct could be defined with empty RetainCallee and ReleaseCallee methods.
//
// The DISABLE_RUNNABLE_METHOD_REFCOUNT macro is provided as a convenient way
// for declaring a CefRunnableMethodTraits that disables refcounting.

template <class T>
struct CefRunnableMethodTraits {
  CefRunnableMethodTraits() {
  }

  ~CefRunnableMethodTraits() {
  }

  void RetainCallee(T* obj) {
#ifndef NDEBUG
    // Catch NewCefRunnableMethod being called in an object's constructor.
    // This isn't safe since the method can be invoked before the constructor
    // completes, causing the object to be deleted.
    obj->AddRef();
    obj->Release();
#endif
    obj->AddRef();
  }

  void ReleaseCallee(T* obj) {
    obj->Release();
  }
};

// Convenience macro for declaring a CefRunnableMethodTraits that disables
// refcounting of a class.  This is useful if you know that the callee
// will outlive the CefRunnableMethod object and thus do not need the ref
// counts.
//
// The invocation of DISABLE_RUNNABLE_METHOD_REFCOUNT should be done at the
// global namespace scope.  Example:
//
//   namespace foo {
//   class Bar {
//     ...
//   };
//   }  // namespace foo
//
//   DISABLE_RUNNABLE_METHOD_REFCOUNT(foo::Bar);
//
// This is different from DISALLOW_COPY_AND_ASSIGN which is declared inside the
// class.
#define DISABLE_RUNNABLE_METHOD_REFCOUNT(TypeName) \
  template <>                                      \
  struct CefRunnableMethodTraits<TypeName> {          \
    void RetainCallee(TypeName* manager) {}        \
    void ReleaseCallee(TypeName* manager) {}       \
  }

// CefRunnableMethod and CefRunnableFunction ----------------------------------
//
// CefRunnable methods are a type of task that call a function on an object
// when they are run. We implement both an object and a set of
// NewCefRunnableMethod and NewCefRunnableFunction functions for convenience.
// These functions are overloaded and will infer the template types,
// simplifying calling code.
//
// The template definitions all use the following names:
// T                - the class type of the object you're supplying
//                    this is not needed for the Static version of the call
// Method/Function  - the signature of a pointer to the method or function you
//                    want to call
// Param            - the parameter(s) to the method, possibly packed as a Tuple
// A                - the first parameter (if any) to the method
// B                - the second parameter (if any) to the method
//
// Put these all together and you get an object that can call a method whose
// signature is:
//   R T::MyFunction([A[, B]])
//
// Usage:
// CefPostTask(TID_UI, NewCefRunnableMethod(object, &Object::method[, a[, b]])
// CefPostTask(TID_UI, NewCefRunnableFunction(&function[, a[, b]])

// CefRunnableMethod and NewCefRunnableMethod implementation ------------------

template <class T, class Method, class Params>
class CefRunnableMethod : public CefTask {
 public:
  CefRunnableMethod(T* obj, Method meth, const Params& params)
      : obj_(obj), meth_(meth), params_(params) {
    traits_.RetainCallee(obj_);
  }

  ~CefRunnableMethod() {
    T* obj = obj_;
    obj_ = NULL;
    if (obj)
      traits_.ReleaseCallee(obj);
  }

  virtual void Execute(CefThreadId threadId) {
    if (obj_)
      DispatchToMethod(obj_, meth_, params_);
  }

 private:
  T* obj_;
  Method meth_;
  Params params_;
  CefRunnableMethodTraits<T> traits_;

  IMPLEMENT_REFCOUNTING(CefRunnableMethod);
};

template <class T, class Method>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method) {
  return new CefRunnableMethod<T, Method, Tuple0>(object, method, MakeTuple());
}

template <class T, class Method, class A>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method,
                                               const A& a) {
  return new CefRunnableMethod<T, Method, Tuple1<A> >(object,
                                                      method,
                                                      MakeTuple(a));
}

template <class T, class Method, class A, class B>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method,
                                               const A& a, const B& b) {
  return new CefRunnableMethod<T, Method, Tuple2<A, B> >(object, method,
                                                         MakeTuple(a, b));
}

template <class T, class Method, class A, class B, class C>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method,
                                               const A& a, const B& b,
                                               const C& c) {
  return new CefRunnableMethod<T, Method, Tuple3<A, B, C> >(object, method,
                                                            MakeTuple(a, b,
                                                                      c));
}

template <class T, class Method, class A, class B, class C, class D>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method,
                                               const A& a, const B& b,
                                               const C& c, const D& d) {
  return new CefRunnableMethod<T, Method, Tuple4<A, B, C, D> >(object, method,
                                                               MakeTuple(a, b,
                                                                         c,
                                                                         d));
}

template <class T, class Method, class A, class B, class C, class D, class E>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method,
                                               const A& a, const B& b,
                                               const C& c, const D& d,
                                               const E& e) {
  return new CefRunnableMethod<T,
                               Method,
                               Tuple5<A, B, C, D, E> >(object,
                                                       method,
                                                       MakeTuple(a, b, c, d,
                                                                 e));
}

template <class T, class Method, class A, class B, class C, class D, class E,
          class F>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method,
                                               const A& a, const B& b,
                                               const C& c, const D& d,
                                               const E& e, const F& f) {
  return new CefRunnableMethod<T,
                               Method,
                               Tuple6<A, B, C, D, E, F> >(object,
                                                          method,
                                                          MakeTuple(a, b, c, d,
                                                                    e, f));
}

template <class T, class Method, class A, class B, class C, class D, class E,
          class F, class G>
inline CefRefPtr<CefTask> NewCefRunnableMethod(T* object, Method method,
                                               const A& a, const B& b,
                                               const C& c, const D& d,
                                               const E& e, const F& f,
                                               const G& g) {
  return new CefRunnableMethod<T,
                               Method,
                               Tuple7<A, B, C, D, E, F, G> >(object,
                                                             method,
                                                             MakeTuple(a, b, c,
                                                                       d, e, f,
                                                                       g));
}

// CefRunnableFunction and NewCefRunnableFunction implementation --------------

template <class Function, class Params>
class CefRunnableFunction : public CefTask {
 public:
  CefRunnableFunction(Function function, const Params& params)
      : function_(function), params_(params) {
  }

  ~CefRunnableFunction() {
  }

  virtual void Execute(CefThreadId threadId) {
    if (function_)
      DispatchToFunction(function_, params_);
  }

 private:
  Function function_;
  Params params_;

  IMPLEMENT_REFCOUNTING(CefRunnableFunction);
};

template <class Function>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function) {
  return new CefRunnableFunction<Function, Tuple0>(function, MakeTuple());
}

template <class Function, class A>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a) {
  return new CefRunnableFunction<Function, Tuple1<A> >(function, MakeTuple(a));
}

template <class Function, class A, class B>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a, const B& b) {
  return new CefRunnableFunction<Function, Tuple2<A, B> >(function,
                                                          MakeTuple(a, b));
}

template <class Function, class A, class B, class C>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a, const B& b,
                                                 const C& c) {
  return new CefRunnableFunction<Function, Tuple3<A, B, C> >(function,
                                                             MakeTuple(a, b,
                                                                       c));
}

template <class Function, class A, class B, class C, class D>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a, const B& b,
                                                 const C& c, const D& d) {
  return new CefRunnableFunction<Function, Tuple4<A, B, C, D> >(function,
                                                                MakeTuple(a, b,
                                                                          c,
                                                                          d));
}

template <class Function, class A, class B, class C, class D, class E>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a, const B& b,
                                                 const C& c, const D& d,
                                                 const E& e) {
  return new CefRunnableFunction<Function, Tuple5<A, B, C, D, E> >(function,
      MakeTuple(a, b, c, d, e));
}

template <class Function, class A, class B, class C, class D, class E,
          class F>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a, const B& b,
                                                 const C& c, const D& d,
                                                 const E& e, const F& f) {
  return new CefRunnableFunction<Function, Tuple6<A, B, C, D, E, F> >(function,
      MakeTuple(a, b, c, d, e, f));
}

template <class Function, class A, class B, class C, class D, class E,
          class F, class G>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a, const B& b,
                                                 const C& c, const D& d,
                                                 const E& e, const F& f,
                                                 const G& g) {
  return new CefRunnableFunction<Function, Tuple7<A, B, C, D, E, F, G> >(
      function, MakeTuple(a, b, c, d, e, f, g));
}

template <class Function, class A, class B, class C, class D, class E,
          class F, class G, class H>
inline CefRefPtr<CefTask> NewCefRunnableFunction(Function function,
                                                 const A& a, const B& b,
                                                 const C& c, const D& d,
                                                 const E& e, const F& f,
                                                 const G& g, const H& h) {
  return new CefRunnableFunction<Function, Tuple8<A, B, C, D, E, F, G, H> >(
      function, MakeTuple(a, b, c, d, e, f, g, h));
}

#endif  // CEF_INCLUDE_CEF_RUNNABLE_H_
