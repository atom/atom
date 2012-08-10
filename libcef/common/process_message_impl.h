// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_PROCESS_MESSAGE_IMPL_H_
#define CEF_LIBCEF_COMMON_PROCESS_MESSAGE_IMPL_H_
#pragma once

#include "include/cef_process_message.h"
#include "libcef/common/value_base.h"

struct Cef_Request_Params;

// CefProcessMessage implementation
class CefProcessMessageImpl
    : public CefValueBase<CefProcessMessage, Cef_Request_Params> {
 public:
  CefProcessMessageImpl(Cef_Request_Params* value,
                        bool will_delete,
                        bool read_only);

  // Copies the underlying value to the specified |target| structure.
  bool CopyTo(Cef_Request_Params& target);

  // CefProcessMessage methods.
  virtual bool IsValid() OVERRIDE;
  virtual bool IsReadOnly() OVERRIDE;
  virtual CefRefPtr<CefProcessMessage> Copy() OVERRIDE;
  virtual CefString GetName() OVERRIDE;
  virtual CefRefPtr<CefListValue> GetArgumentList() OVERRIDE;

  DISALLOW_COPY_AND_ASSIGN(CefProcessMessageImpl);
};

#endif  // CEF_LIBCEF_COMMON_PROCESS_MESSAGE_IMPL_H_
