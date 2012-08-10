// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/common/scheme_registrar_impl.h"

#include <string>

#include "libcef/renderer/content_renderer_client.h"

#include "base/bind.h"
#include "base/logging.h"

CefSchemeRegistrarImpl::CefSchemeRegistrarImpl()
    : supported_thread_id_(base::PlatformThread::CurrentId()) {
}

bool CefSchemeRegistrarImpl::AddCustomScheme(
    const CefString& scheme_name,
    bool is_standard,
    bool is_local,
    bool is_display_isolated) {
  if (!VerifyContext())
    return false;

  if (is_standard)
    standard_schemes_.push_back(scheme_name);

  if (CefContentRendererClient::Get()) {
    // Register the custom scheme with WebKit.
    CefContentRendererClient::Get()->AddCustomScheme(scheme_name, is_local,
                                                     is_display_isolated);
  }

  return true;
}

void CefSchemeRegistrarImpl::GetStandardSchemes(
    std::vector<std::string>* standard_schemes) {
  if (!VerifyContext())
    return;

  if (standard_schemes_.empty())
    return;

  standard_schemes->insert(standard_schemes->end(), standard_schemes_.begin(),
                           standard_schemes_.end());
}

bool CefSchemeRegistrarImpl::VerifyRefCount() {
  return (GetRefCt() == 1);
}

void CefSchemeRegistrarImpl::Detach() {
  if (VerifyContext())
    supported_thread_id_ = base::kInvalidThreadId;
}

bool CefSchemeRegistrarImpl::VerifyContext() {
  if (base::PlatformThread::CurrentId() != supported_thread_id_) {
    // This object should only be accessed from the thread that created it.
    NOTREACHED();
    return false;
  }

  return true;
}
