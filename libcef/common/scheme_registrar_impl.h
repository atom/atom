// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_SCHEME_REGISTRAR_IMPL_H_
#define CEF_LIBCEF_COMMON_SCHEME_REGISTRAR_IMPL_H_
#pragma once

#include <string>
#include <vector>

#include "include/cef_scheme.h"

#include "base/threading/platform_thread.h"

class CefSchemeRegistrarImpl : public CefSchemeRegistrar {
 public:
  CefSchemeRegistrarImpl();

  // CefSchemeRegistrar methods.
  virtual bool AddCustomScheme(const CefString& scheme_name,
                               bool is_standard,
                               bool is_local,
                               bool is_display_isolated) OVERRIDE;

  void GetStandardSchemes(std::vector<std::string>* standard_schemes);

  // Verify that only a single reference exists to all CefSchemeRegistrarImpl
  // objects.
  bool VerifyRefCount();

  void Detach();

 private:
  // Verify that the object is being accessed from the correct thread.
  bool VerifyContext();

  base::PlatformThreadId supported_thread_id_;

  std::vector<std::string> standard_schemes_;

  IMPLEMENT_REFCOUNTING(CefSchemeRegistrarImpl);
  DISALLOW_COPY_AND_ASSIGN(CefSchemeRegistrarImpl);
};

#endif  // CEF_LIBCEF_COMMON_SCHEME_REGISTRAR_IMPL_H_
