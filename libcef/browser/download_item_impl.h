// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_DOWNLOAD_ITEM_IMPL_H_
#define CEF_LIBCEF_BROWSER_DOWNLOAD_ITEM_IMPL_H_
#pragma once

#include "include/cef_download_item.h"
#include "libcef/common/value_base.h"

namespace content {
class DownloadItem;
}

// CefDownloadItem implementation
class CefDownloadItemImpl
    : public CefValueBase<CefDownloadItem, content::DownloadItem> {
 public:
  explicit CefDownloadItemImpl(content::DownloadItem* value);

  // CefDownloadItem methods.
  virtual bool IsValid() OVERRIDE;
  virtual bool IsInProgress() OVERRIDE;
  virtual bool IsComplete() OVERRIDE;
  virtual bool IsCanceled() OVERRIDE;
  virtual int64 GetCurrentSpeed() OVERRIDE;
  virtual int GetPercentComplete() OVERRIDE;
  virtual int64 GetTotalBytes() OVERRIDE;
  virtual int64 GetReceivedBytes() OVERRIDE;
  virtual CefTime GetStartTime() OVERRIDE;
  virtual CefTime GetEndTime() OVERRIDE;
  virtual CefString GetFullPath() OVERRIDE;
  virtual int32 GetId() OVERRIDE;
  virtual CefString GetURL() OVERRIDE;
  virtual CefString GetSuggestedFileName() OVERRIDE;
  virtual CefString GetContentDisposition() OVERRIDE;
  virtual CefString GetMimeType() OVERRIDE;
  virtual CefString GetReferrerCharset() OVERRIDE;

 private:
  DISALLOW_COPY_AND_ASSIGN(CefDownloadItemImpl);
};

#endif  // CEF_LIBCEF_BROWSER_DOWNLOAD_ITEM_IMPL_H_
