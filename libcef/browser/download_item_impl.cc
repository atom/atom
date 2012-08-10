// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/browser/download_item_impl.h"

#include "libcef/common/time_util.h"

#include "content/public/browser/download_item.h"
#include "googleurl/src/gurl.h"


CefDownloadItemImpl::CefDownloadItemImpl(content::DownloadItem* value)
  : CefValueBase<CefDownloadItem, content::DownloadItem>(
        value, NULL, kOwnerNoDelete, true,
        new CefValueControllerNonThreadSafe()) {
  // Indicate that this object owns the controller.
  SetOwnsController();
}

bool CefDownloadItemImpl::IsValid() {
  return !detached();
}

bool CefDownloadItemImpl::IsInProgress() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return const_value().IsInProgress();
}

bool CefDownloadItemImpl::IsComplete() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return const_value().IsComplete();
}

bool CefDownloadItemImpl::IsCanceled() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return const_value().IsCancelled();
}

int64 CefDownloadItemImpl::GetCurrentSpeed() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().CurrentSpeed();
}

int CefDownloadItemImpl::GetPercentComplete() {
  CEF_VALUE_VERIFY_RETURN(false, -1);
  return const_value().PercentComplete();
}

int64 CefDownloadItemImpl::GetTotalBytes() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().GetTotalBytes();
}

int64 CefDownloadItemImpl::GetReceivedBytes() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().GetReceivedBytes();
}

CefTime CefDownloadItemImpl::GetStartTime() {
  CefTime time;
  CEF_VALUE_VERIFY_RETURN(false, time);
  cef_time_from_basetime(const_value().GetStartTime(), time);
  return time;
}

CefTime CefDownloadItemImpl::GetEndTime() {
  CefTime time;
  CEF_VALUE_VERIFY_RETURN(false, time);
  cef_time_from_basetime(const_value().GetEndTime(), time);
  return time;
}

CefString CefDownloadItemImpl::GetFullPath() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetFullPath().value();
}

int32 CefDownloadItemImpl::GetId() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().GetId();
}

CefString CefDownloadItemImpl::GetURL() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetURL().spec();
}

CefString CefDownloadItemImpl::GetSuggestedFileName() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetSuggestedFilename();
}

CefString CefDownloadItemImpl::GetContentDisposition() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetContentDisposition();
}

CefString CefDownloadItemImpl::GetMimeType() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetMimeType();
}

CefString CefDownloadItemImpl::GetReferrerCharset() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetReferrerCharset();
}
