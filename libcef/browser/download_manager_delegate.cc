// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/download_manager_delegate.h"

#include "include/cef_download_handler.h"
#include "libcef/browser/browser_context.h"
#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/context.h"
#include "libcef/browser/download_item_impl.h"
#include "libcef/browser/thread_util.h"

#include "base/bind.h"
#include "base/file_util.h"
#include "base/logging.h"
#include "base/path_service.h"
#include "base/string_util.h"
#include "base/utf_string_conversions.h"
#include "content/public/browser/browser_context.h"
#include "content/public/browser/download_manager.h"
#include "content/public/browser/web_contents.h"
#include "net/base/net_util.h"

using content::DownloadItem;
using content::DownloadManager;
using content::WebContents;


namespace {

// Helper function to retrieve the CefBrowserHostImpl.
CefRefPtr<CefBrowserHostImpl> GetBrowser(DownloadItem* item) {
  content::WebContents* contents = item->GetWebContents();
  if (!contents)
    return NULL;

  return CefBrowserHostImpl::GetBrowserForContents(contents).get();
}

// Helper function to retrieve the CefDownloadHandler.
CefRefPtr<CefDownloadHandler> GetDownloadHandler(
    CefRefPtr<CefBrowserHostImpl> browser) {
  CefRefPtr<CefClient> client = browser->GetClient();
  if (client.get())
    return client->GetDownloadHandler();
  return NULL;
}

// Helper function to retrieve the DownloadManager.
scoped_refptr<content::DownloadManager> GetDownloadManager() {
  return content::BrowserContext::GetDownloadManager(
      _Context->browser_context());
}


// CefBeforeDownloadCallback implementation.
class CefBeforeDownloadCallbackImpl : public CefBeforeDownloadCallback {
 public:
  CefBeforeDownloadCallbackImpl(int32 download_id,
                                const FilePath& suggested_name)
    : download_id_(download_id),
      suggested_name_(suggested_name) {
  }

  virtual void Continue(const CefString& download_path,
                        bool show_dialog) OVERRIDE {
    if (CEF_CURRENTLY_ON_UIT()) {
      if (download_id_ <= 0)
        return;

      scoped_refptr<content::DownloadManager> manager = GetDownloadManager();
      if (manager) {
        FilePath path = FilePath(download_path);
        CEF_POST_TASK(CEF_FILET,
            base::Bind(&CefBeforeDownloadCallbackImpl::GenerateFilename,
                       download_id_, suggested_name_, path, show_dialog));
      }

      download_id_ = 0;
    } else {
      CEF_POST_TASK(CEF_UIT,
          base::Bind(&CefBeforeDownloadCallbackImpl::Continue, this,
                     download_path, show_dialog));
    }
  }

 private:
  static void GenerateFilename(int32 download_id,
                               const FilePath& suggested_name,
                               const FilePath& download_path,
                               bool show_dialog) {
    FilePath suggested_path = download_path;
    if (!suggested_path.empty()) {
      // Create the directory if necessary.
      FilePath dir_path = suggested_path.DirName();
      if (!file_util::DirectoryExists(dir_path) &&
          !file_util::CreateDirectory(dir_path)) {
        NOTREACHED() << "failed to create the download directory";
        suggested_path.clear();
      }
    }

    if (suggested_path.empty()) {
      if (PathService::Get(base::DIR_TEMP, &suggested_path)) {
        // Use the temp directory.
        suggested_path = suggested_path.Append(suggested_name);
      } else {
        // Use the current working directory.
        suggested_path = suggested_name;
      }
    }

    content::DownloadItem::TargetDisposition disposition = show_dialog ?
        DownloadItem::TARGET_DISPOSITION_PROMPT :
        DownloadItem::TARGET_DISPOSITION_OVERWRITE;

    CEF_POST_TASK(CEF_UIT,
        base::Bind(&CefBeforeDownloadCallbackImpl::RestartDownload,
                   download_id, suggested_path, disposition));
  }

  static void RestartDownload(int32 download_id,
                              const FilePath& suggested_path,
                              DownloadItem::TargetDisposition disposition) {
    scoped_refptr<content::DownloadManager> manager = GetDownloadManager();
    if (!manager)
      return;

    DownloadItem* item = manager->GetActiveDownloadItem(download_id);
    if (!item)
      return;

    item->OnTargetPathDetermined(suggested_path,
                                 disposition,
                                 content::DOWNLOAD_DANGER_TYPE_NOT_DANGEROUS);
    manager->RestartDownload(download_id);
  }

  int32 download_id_;
  FilePath suggested_name_;

  IMPLEMENT_REFCOUNTING(CefBeforeDownloadCallbackImpl);
  DISALLOW_COPY_AND_ASSIGN(CefBeforeDownloadCallbackImpl);
};


// CefDownloadItemCallback implementation.
class CefDownloadItemCallbackImpl : public CefDownloadItemCallback {
 public:
  explicit CefDownloadItemCallbackImpl(int32 download_id)
    : download_id_(download_id) {
  }

  virtual void Cancel() OVERRIDE {
     CEF_POST_TASK(CEF_UIT,
        base::Bind(&CefDownloadItemCallbackImpl::DoCancel, this));
  }

 private:
  void DoCancel() {
    if (download_id_ <= 0)
      return;

    scoped_refptr<content::DownloadManager> manager = GetDownloadManager();
    if (manager) {
      content::DownloadItem* item =
          manager->GetActiveDownloadItem(download_id_);
      if (item && item->IsInProgress())
        item->Cancel(true);
    }

    download_id_ = 0;
  }

  int32 download_id_;

  IMPLEMENT_REFCOUNTING(CefDownloadItemCallbackImpl);
  DISALLOW_COPY_AND_ASSIGN(CefDownloadItemCallbackImpl);
};

}  // namespace


CefDownloadManagerDelegate::CefDownloadManagerDelegate() {
}

CefDownloadManagerDelegate::~CefDownloadManagerDelegate() {
}

bool CefDownloadManagerDelegate::ShouldStartDownload(int32 download_id) {
  scoped_refptr<content::DownloadManager> manager = GetDownloadManager();
  DownloadItem* item = manager->GetActiveDownloadItem(download_id);

  if (!item->GetForcedFilePath().empty()) {
    item->OnTargetPathDetermined(
        item->GetForcedFilePath(),
        DownloadItem::TARGET_DISPOSITION_OVERWRITE,
        content::DOWNLOAD_DANGER_TYPE_NOT_DANGEROUS);
    return true;
  }

  CefRefPtr<CefBrowserHostImpl> browser = GetBrowser(item);
  CefRefPtr<CefDownloadHandler> handler;
  if (browser.get())
    handler = GetDownloadHandler(browser);

  if (handler.get()) {
    FilePath suggested_name = net::GenerateFileName(
        item->GetURL(),
        item->GetContentDisposition(),
        item->GetReferrerCharset(),
        item->GetSuggestedFilename(),
        item->GetMimeType(),
        "download");

    CefRefPtr<CefDownloadItemImpl> download_item(new CefDownloadItemImpl(item));
    CefRefPtr<CefBeforeDownloadCallback> callback(
        new CefBeforeDownloadCallbackImpl(download_id, suggested_name));

    handler->OnBeforeDownload(browser.get(), download_item.get(),
                              suggested_name.value(), callback);

    download_item->Detach(NULL);
  }

  return false;
}

void CefDownloadManagerDelegate::ChooseDownloadPath(
    content::DownloadItem* item) {
  FilePath result;
#if defined(OS_WIN) || defined(OS_MACOSX)
  WebContents* web_contents = item->GetWebContents();
  const FilePath suggested_path(item->GetTargetFilePath());
  result = PlatformChooseDownloadPath(web_contents, suggested_path);
#else
  NOTIMPLEMENTED();
#endif

  scoped_refptr<content::DownloadManager> manager = GetDownloadManager();
  if (result.empty()) {
    manager->FileSelectionCanceled(item->GetId());
  } else {
    manager->FileSelected(result, item->GetId());
  }
}

void CefDownloadManagerDelegate::AddItemToPersistentStore(
    DownloadItem* item) {
  static int next_id;
  scoped_refptr<content::DownloadManager> manager = GetDownloadManager();
  manager->OnItemAddedToPersistentStore(item->GetId(), ++next_id);
}

void CefDownloadManagerDelegate::UpdateItemInPersistentStore(
    DownloadItem* item) {
  CefRefPtr<CefBrowserHostImpl> browser = GetBrowser(item);
  CefRefPtr<CefDownloadHandler> handler;
  if (browser.get())
    handler = GetDownloadHandler(browser);

  if (handler.get()) {
    CefRefPtr<CefDownloadItemImpl> download_item(new CefDownloadItemImpl(item));
    CefRefPtr<CefDownloadItemCallback> callback(
        new CefDownloadItemCallbackImpl(item->GetId()));

    handler->OnDownloadUpdated(browser.get(), download_item.get(), callback);

    download_item->Detach(NULL);
  }
}
