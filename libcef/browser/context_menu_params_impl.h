// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_CONTEXT_MENU_PARAMS_IMPL_H_
#define CEF_LIBCEF_BROWSER_CONTEXT_MENU_PARAMS_IMPL_H_
#pragma once

#include "include/cef_context_menu_handler.h"
#include "libcef/common/value_base.h"

#include "content/public/common/context_menu_params.h"

// CefContextMenuParams implementation. This class is not thread safe.
class CefContextMenuParamsImpl
    : public CefValueBase<CefContextMenuParams, content::ContextMenuParams> {
 public:
  explicit CefContextMenuParamsImpl(content::ContextMenuParams* value);

  // CefContextMenuParams methods.
  virtual int GetXCoord() OVERRIDE;
  virtual int GetYCoord() OVERRIDE;
  virtual TypeFlags GetTypeFlags() OVERRIDE;
  virtual CefString GetLinkUrl() OVERRIDE;
  virtual CefString GetUnfilteredLinkUrl() OVERRIDE;
  virtual CefString GetSourceUrl() OVERRIDE;
  virtual bool IsImageBlocked() OVERRIDE;
  virtual CefString GetPageUrl() OVERRIDE;
  virtual CefString GetFrameUrl() OVERRIDE;
  virtual CefString GetFrameCharset() OVERRIDE;
  virtual MediaType GetMediaType() OVERRIDE;
  virtual MediaStateFlags GetMediaStateFlags() OVERRIDE;
  virtual CefString GetSelectionText() OVERRIDE;
  virtual bool IsEditable() OVERRIDE;
  virtual bool IsSpeechInputEnabled() OVERRIDE;
  virtual EditStateFlags GetEditStateFlags() OVERRIDE;

  DISALLOW_COPY_AND_ASSIGN(CefContextMenuParamsImpl);
};

#endif  // CEF_LIBCEF_BROWSER_CONTEXT_MENU_PARAMS_IMPL_H_
