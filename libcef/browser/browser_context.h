// Copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_BROWSER_CONTEXT_H_
#define CEF_LIBCEF_BROWSER_BROWSER_CONTEXT_H_
#pragma once

#include "base/compiler_specific.h"
#include "base/file_path.h"
#include "base/memory/ref_counted.h"
#include "base/memory/scoped_ptr.h"
#include "content/public/browser/browser_context.h"

namespace content {
class DownloadManagerDelegate;
class SpeechRecognitionPreferences;
}

class CefDownloadManagerDelegate;
class CefResourceContext;

class CefBrowserContext : public content::BrowserContext {
 public:
  CefBrowserContext();
  virtual ~CefBrowserContext();

  // BrowserContext methods.
  virtual FilePath GetPath() OVERRIDE;
  virtual bool IsOffTheRecord() const OVERRIDE;
  virtual content::DownloadManagerDelegate* GetDownloadManagerDelegate() OVERRIDE;
  virtual net::URLRequestContextGetter* GetRequestContext() OVERRIDE;
  virtual net::URLRequestContextGetter* GetRequestContextForRenderProcess(
      int renderer_child_id) OVERRIDE;
  virtual net::URLRequestContextGetter* GetRequestContextForMedia() OVERRIDE;
  virtual content::ResourceContext* GetResourceContext() OVERRIDE;
  virtual content::GeolocationPermissionContext*
      GetGeolocationPermissionContext() OVERRIDE;
  virtual content::SpeechRecognitionPreferences*
      GetSpeechRecognitionPreferences() OVERRIDE;
  virtual bool DidLastSessionExitCleanly() OVERRIDE;
  virtual quota::SpecialStoragePolicy* GetSpecialStoragePolicy() OVERRIDE;

 private:

  scoped_ptr<CefResourceContext> resource_context_;
  scoped_refptr<CefDownloadManagerDelegate> download_manager_delegate_;
  scoped_refptr<net::URLRequestContextGetter> url_request_getter_;
  scoped_refptr<content::GeolocationPermissionContext>
      geolocation_permission_context_;
  scoped_refptr<content::SpeechRecognitionPreferences>
      speech_recognition_preferences_;

  DISALLOW_COPY_AND_ASSIGN(CefBrowserContext);
};

#endif  // CEF_LIBCEF_BROWSER_BROWSER_CONTEXT_H_
