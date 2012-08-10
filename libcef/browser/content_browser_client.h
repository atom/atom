// Copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_CONTENT_BROWSER_CLIENT_H_
#define CEF_LIBCEF_BROWSER_CONTENT_BROWSER_CLIENT_H_
#pragma once

#include <string>
#include <utility>
#include <vector>

#include "base/compiler_specific.h"
#include "base/memory/scoped_ptr.h"
#include "content/public/browser/content_browser_client.h"

class CefBrowserMainParts;
class CefMediaObserver;
class CefResourceDispatcherHostDelegate;

namespace content {
class SiteInstance;
}

class CefContentBrowserClient : public content::ContentBrowserClient {
 public:
  CefContentBrowserClient();
  virtual ~CefContentBrowserClient();

  CefBrowserMainParts* browser_main_parts() const {
    return browser_main_parts_;
  }

  virtual content::BrowserMainParts* CreateBrowserMainParts(
      const content::MainFunctionParams& parameters) OVERRIDE;
  virtual void RenderProcessHostCreated(
      content::RenderProcessHost* host) OVERRIDE;
  virtual void AppendExtraCommandLineSwitches(CommandLine* command_line,
                                              int child_process_id) OVERRIDE;
  virtual content::MediaObserver* GetMediaObserver() OVERRIDE;
  virtual content::AccessTokenStore* CreateAccessTokenStore() OVERRIDE;
  virtual void ResourceDispatcherHostCreated() OVERRIDE;
  virtual void OverrideWebkitPrefs(content::RenderViewHost* rvh,
                                   const GURL& url,
                                   webkit_glue::WebPreferences* prefs) OVERRIDE;
  virtual std::string GetDefaultDownloadName() OVERRIDE;

 private:
  CefBrowserMainParts* browser_main_parts_;

  scoped_ptr<CefMediaObserver> media_observer_;
  scoped_ptr<CefResourceDispatcherHostDelegate>
      resource_dispatcher_host_delegate_;
};

#endif  // CEF_LIBCEF_BROWSER_CONTENT_BROWSER_CLIENT_H_
