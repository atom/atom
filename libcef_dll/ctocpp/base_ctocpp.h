// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_DLL_CTOCPP_BASE_CTOCPP_H_
#define CEF_LIBCEF_DLL_CTOCPP_BASE_CTOCPP_H_
#pragma once

#include "include/cef_base.h"
#include "include/capi/cef_base_capi.h"
#include "libcef_dll/cef_logging.h"


// CefCToCpp implementation for CefBase.
class CefBaseCToCpp : public CefBase {
 public:
  // Use this method to create a wrapper class instance for a structure
  // received from the other side.
  static CefRefPtr<CefBase> Wrap(cef_base_t* s) {
    if (!s)
      return NULL;

    // Wrap their structure with the CefCToCpp object.
    CefBaseCToCpp* wrapper = new CefBaseCToCpp(s);
    // Put the wrapper object in a smart pointer.
    CefRefPtr<CefBase> wrapperPtr(wrapper);
    // Release the reference that was added to the CefCppToC wrapper object on
    // the other side before their structure was passed to us.
    wrapper->UnderlyingRelease();
    // Return the smart pointer.
    return wrapperPtr;
  }

  // Use this method to retrieve the underlying structure from a wrapper class
  // instance for return back to the other side.
  static cef_base_t* Unwrap(CefRefPtr<CefBase> c) {
    if (!c.get())
      return NULL;

    // Cast the object to our wrapper class type.
    CefBaseCToCpp* wrapper = static_cast<CefBaseCToCpp*>(c.get());
    // Add a reference to the CefCppToC wrapper object on the other side that
    // will be released once the structure is received.
    wrapper->UnderlyingAddRef();
    // Return their original structure.
    return wrapper->GetStruct();
  }

  explicit CefBaseCToCpp(cef_base_t* str)
    : struct_(str) {
    DCHECK(str);
  }
  virtual ~CefBaseCToCpp() {}

  // If returning the structure across the DLL boundary you should call
  // UnderlyingAddRef() on this wrapping CefCToCpp object.  On the other side of
  // the DLL  boundary, call Release() on the CefCppToC object.
  cef_base_t* GetStruct() { return struct_; }

  // CefBase methods increment/decrement reference counts on both this object
  // and the underlying wrapped structure.
  int AddRef() {
    UnderlyingAddRef();
    return refct_.AddRef();
  }
  int Release() {
    UnderlyingRelease();
    int retval = refct_.Release();
    if (retval == 0)
      delete this;
    return retval;
  }
  int GetRefCt() { return refct_.GetRefCt(); }

  // Increment/decrement reference counts on only the underlying class.
  int UnderlyingAddRef() {
    if (!struct_->add_ref)
      return 0;
    return struct_->add_ref(struct_);
  }
  int UnderlyingRelease() {
    if (!struct_->release)
      return 0;
    return struct_->release(struct_);
  }
  int UnderlyingGetRefCt() {
    if (!struct_->get_refct)
      return 0;
    return struct_->get_refct(struct_);
  }

 protected:
  CefRefCount refct_;
  cef_base_t* struct_;
};


#endif  // CEF_LIBCEF_DLL_CTOCPP_BASE_CTOCPP_H_
