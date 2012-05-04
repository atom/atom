// Copyright (c) 2008 Marshall A. Greenblatt. Portions Copyright (c)
// 2006-2008 Google Inc. All rights reserved.
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


#ifndef CEF_INCLUDE_INTERNAL_CEF_PTR_H_
#define CEF_INCLUDE_INTERNAL_CEF_PTR_H_
#pragma once

#include <stddef.h>

///
// Smart pointer implementation borrowed from base/ref_counted.h
// <p>
// A smart pointer class for reference counted objects.  Use this class instead
// of calling AddRef and Release manually on a reference counted object to
// avoid common memory leaks caused by forgetting to Release an object
// reference.  Sample usage:
// <pre>
//   class MyFoo : public CefBase {
//    ...
//   };
//
//   void some_function() {
//     // The MyFoo object that |foo| represents starts with a single
//     // reference.
//     CefRefPtr&lt;MyFoo&gt; foo = new MyFoo();
//     foo-&gt;Method(param);
//     // |foo| is released when this function returns
//   }
//
//   void some_other_function() {
//     CefRefPtr&lt;MyFoo&gt; foo = new MyFoo();
//     ...
//     foo = NULL;  // explicitly releases |foo|
//     ...
//     if (foo)
//       foo-&gt;Method(param);
//   }
// </pre>
// The above examples show how CefRefPtr&lt;T&gt; acts like a pointer to T.
// Given two CefRefPtr&lt;T&gt; classes, it is also possible to exchange
// references between the two objects, like so:
// <pre>
//   {
//     CefRefPtr&lt;MyFoo&gt; a = new MyFoo();
//     CefRefPtr&lt;MyFoo&gt; b;
//
//     b.swap(a);
//     // now, |b| references the MyFoo object, and |a| references NULL.
//   }
// </pre>
// To make both |a| and |b| in the above example reference the same MyFoo
// object, simply use the assignment operator:
// <pre>
//   {
//     CefRefPtr&lt;MyFoo&gt; a = new MyFoo();
//     CefRefPtr&lt;MyFoo&gt; b;
//
//     b = a;
//     // now, |a| and |b| each own a reference to the same MyFoo object.
//     // the reference count of the underlying MyFoo object will be 2.
//   }
// </pre>
// Reference counted objects can also be passed as function parameters and
// used as function return values:
// <pre>
//   void some_func_with_param(CefRefPtr&lt;MyFoo&gt; param) {
//     // A reference is added to the MyFoo object that |param| represents
//     // during the scope of some_func_with_param() and released when
//     // some_func_with_param() goes out of scope.
//   }
//
//   CefRefPtr&lt;MyFoo&gt; some_func_with_retval() {
//     // The MyFoo object that |foox| represents starts with a single
//     // reference.
//     CefRefPtr&lt;MyFoo&gt; foox = new MyFoo();
//
//     // Creating the return value adds an additional reference.
//     return foox;
//
//     // When some_func_with_retval() goes out of scope the original |foox|
//     // reference is released.
//   }
//
//   void and_another_function() {
//     CefRefPtr&lt;MyFoo&gt; foo = new MyFoo();
//
//     // pass |foo| as a parameter.
//     some_function(foo);
//
//     CefRefPtr&lt;MyFoo&gt; foo2 = some_func_with_retval();
//     // Now, since we kept a reference to the some_func_with_retval() return
//     // value, |foo2| is the only class pointing to the MyFoo object created
//     in some_func_with_retval(), and it has a reference count of 1.
//
//     some_func_with_retval();
//     // Now, since we didn't keep a reference to the some_func_with_retval()
//     // return value, the MyFoo object created in some_func_with_retval()
//     // will automatically be released.
//   }
// </pre>
// And in standard containers:
// <pre>
//   {
//      // Create a vector that holds MyFoo objects.
//      std::vector&lt;CefRefPtr&lt;MyFoo&gt; &gt; MyFooVec;
//
//     // The MyFoo object that |foo| represents starts with a single
//     // reference.
//     CefRefPtr&lt;MyFoo&gt; foo = new MyFoo();
//
//     // When the MyFoo object is added to |MyFooVec| the reference count
//     // is increased to 2.
//     MyFooVec.push_back(foo);
//   }
// </pre>
// </p>
///
template <class T>
class CefRefPtr {
 public:
  CefRefPtr() : ptr_(NULL) {
  }

  CefRefPtr(T* p) : ptr_(p) {  // NOLINT(runtime/explicit)
    if (ptr_)
      ptr_->AddRef();
  }

  CefRefPtr(const CefRefPtr<T>& r) : ptr_(r.ptr_) {
    if (ptr_)
      ptr_->AddRef();
  }

  ~CefRefPtr() {
    if (ptr_)
      ptr_->Release();
  }

  T* get() const { return ptr_; }
  operator T*() const { return ptr_; }
  T* operator->() const { return ptr_; }

  CefRefPtr<T>& operator=(T* p) {
    // AddRef first so that self assignment should work
    if (p)
      p->AddRef();
    if (ptr_ )
      ptr_ ->Release();
    ptr_ = p;
    return *this;
  }

  CefRefPtr<T>& operator=(const CefRefPtr<T>& r) {
    return *this = r.ptr_;
  }

  void swap(T** pp) {
    T* p = ptr_;
    ptr_ = *pp;
    *pp = p;
  }

  void swap(CefRefPtr<T>& r) {
    swap(&r.ptr_);  // NOLINT(build/include_what_you_use)
  }

 private:
  T* ptr_;
};

#endif  // CEF_INCLUDE_INTERNAL_CEF_PTR_H_
