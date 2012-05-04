// Copyright (c) 2011 Marshall A. Greenblatt. All rights reserved.
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
// ---------------------------------------------------------------------------
//
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//


#ifndef CEF_INCLUDE_CEF_BASE_H_
#define CEF_INCLUDE_CEF_BASE_H_
#pragma once

#include "include/internal/cef_build.h"
#include "include/internal/cef_ptr.h"
#include "include/internal/cef_types_wrappers.h"

// Bring in platform-specific definitions.
#if defined(OS_WIN)
#include "include/internal/cef_win.h"
#elif defined(OS_MACOSX)
#include "include/internal/cef_mac.h"
#elif defined(OS_LINUX)
#include "include/internal/cef_linux.h"
#endif

///
// Interface defining the reference count implementation methods. All framework
// classes must extend the CefBase class.
///
class CefBase {
 public:
  ///
  // The AddRef method increments the reference count for the object. It should
  // be called for every new copy of a pointer to a given object. The resulting
  // reference count value is returned and should be used for diagnostic/testing
  // purposes only.
  ///
  virtual int AddRef() =0;

  ///
  // The Release method decrements the reference count for the object. If the
  // reference count on the object falls to 0, then the object should free
  // itself from memory.  The resulting reference count value is returned and
  // should be used for diagnostic/testing purposes only.
  ///
  virtual int Release() =0;

  ///
  // Return the current number of references.
  ///
  virtual int GetRefCt() =0;

 protected:
  virtual ~CefBase() {}
};


///
// Class that implements atomic reference counting.
///
class CefRefCount {
 public:
  CefRefCount() : refct_(0) {}

  ///
  // Atomic reference increment.
  ///
  int AddRef() {
    return CefAtomicIncrement(&refct_);
  }

  ///
  // Atomic reference decrement. Delete the object when no references remain.
  ///
  int Release() {
    return CefAtomicDecrement(&refct_);
  }

  ///
  // Return the current number of references.
  ///
  int GetRefCt() { return refct_; }

 private:
  long refct_;  // NOLINT(runtime/int)
};

///
// Macro that provides a reference counting implementation for classes extending
// CefBase.
///
#define IMPLEMENT_REFCOUNTING(ClassName)            \
  public:                                           \
    int AddRef() { return refct_.AddRef(); }        \
    int Release() {                                 \
      int retval = refct_.Release();                \
      if (retval == 0)                              \
        delete this;                                \
      return retval;                                \
    }                                               \
    int GetRefCt() { return refct_.GetRefCt(); }    \
  private:                                          \
    CefRefCount refct_;

///
// Macro that provides a locking implementation. Use the Lock() and Unlock()
// methods to protect a section of code from simultaneous access by multiple
// threads. The AutoLock class is a helper that will hold the lock while in
// scope.
///
#define IMPLEMENT_LOCKING(ClassName)                                       \
  public:                                                                  \
    class AutoLock {                                                       \
     public:                                                               \
      explicit AutoLock(ClassName* base) : base_(base) { base_->Lock(); }  \
      ~AutoLock() { base_->Unlock(); }                                     \
     private:                                                              \
      ClassName* base_;                                                    \
    };                                                                     \
    void Lock() { critsec_.Lock(); }                                       \
    void Unlock() { critsec_.Unlock(); }                                   \
  private:                                                                 \
    CefCriticalSection critsec_;

#endif  // CEF_INCLUDE_CEF_BASE_H_
