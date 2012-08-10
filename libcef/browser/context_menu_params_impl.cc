// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/browser/context_menu_params_impl.h"

#include "base/logging.h"

CefContextMenuParamsImpl::CefContextMenuParamsImpl(
    content::ContextMenuParams* value)
  : CefValueBase<CefContextMenuParams, content::ContextMenuParams>(
        value, NULL, kOwnerNoDelete, true,
        new CefValueControllerNonThreadSafe()) {
  // Indicate that this object owns the controller.
  SetOwnsController();
}

int CefContextMenuParamsImpl::GetXCoord() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().x;
}

int CefContextMenuParamsImpl::GetYCoord() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().y;
}

CefContextMenuParamsImpl::TypeFlags CefContextMenuParamsImpl::GetTypeFlags() {
  CEF_VALUE_VERIFY_RETURN(false, CM_TYPEFLAG_NONE);
  const content::ContextMenuParams& params = const_value();
  int type_flags = CM_TYPEFLAG_NONE;
  if (!params.page_url.is_empty())
    type_flags |= CM_TYPEFLAG_PAGE;
  if (!params.frame_url.is_empty())
    type_flags |= CM_TYPEFLAG_FRAME;
  if (!params.link_url.is_empty())
    type_flags |= CM_TYPEFLAG_LINK;
  if (params.media_type != WebKit::WebContextMenuData::MediaTypeNone)
    type_flags |= CM_TYPEFLAG_MEDIA;
  if (!params.selection_text.empty())
    type_flags |= CM_TYPEFLAG_SELECTION;
  if (params.is_editable)
    type_flags |= CM_TYPEFLAG_EDITABLE;
  return static_cast<TypeFlags>(type_flags);
}

CefString CefContextMenuParamsImpl::GetLinkUrl() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().link_url.spec();
}

CefString CefContextMenuParamsImpl::GetUnfilteredLinkUrl() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().unfiltered_link_url.spec();
}

CefString CefContextMenuParamsImpl::GetSourceUrl() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().src_url.spec();
}

bool CefContextMenuParamsImpl::IsImageBlocked() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return const_value().is_image_blocked;
}

CefString CefContextMenuParamsImpl::GetPageUrl() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().page_url.spec();
}

CefString CefContextMenuParamsImpl::GetFrameUrl() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().frame_url.spec();
}

CefString CefContextMenuParamsImpl::GetFrameCharset() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().frame_charset;
}

CefContextMenuParamsImpl::MediaType CefContextMenuParamsImpl::GetMediaType() {
  CEF_VALUE_VERIFY_RETURN(false, CM_MEDIATYPE_NONE);
  return static_cast<MediaType>(const_value().media_type);
}

CefContextMenuParamsImpl::MediaStateFlags
    CefContextMenuParamsImpl::GetMediaStateFlags() {
  CEF_VALUE_VERIFY_RETURN(false, CM_MEDIAFLAG_NONE);
  return static_cast<MediaStateFlags>(const_value().media_flags);
}

CefString CefContextMenuParamsImpl::GetSelectionText() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().selection_text;
}

bool CefContextMenuParamsImpl::IsEditable() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return const_value().is_editable;
}

bool CefContextMenuParamsImpl::IsSpeechInputEnabled() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return const_value().speech_input_enabled;
}

CefContextMenuParamsImpl::EditStateFlags
    CefContextMenuParamsImpl::GetEditStateFlags() {
  CEF_VALUE_VERIFY_RETURN(false, CM_EDITFLAG_NONE);
  return static_cast<EditStateFlags>(const_value().edit_flags);
}
