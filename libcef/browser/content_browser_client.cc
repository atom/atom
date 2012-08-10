// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/content_browser_client.h"
#include "libcef/browser/browser_context.h"
#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/browser_main.h"
#include "libcef/browser/browser_message_filter.h"
#include "libcef/browser/browser_settings.h"
#include "libcef/browser/context.h"
#include "libcef/browser/resource_dispatcher_host_delegate.h"
#include "libcef/browser/thread_util.h"
#include "libcef/common/cef_switches.h"

#include "base/command_line.h"
#include "base/file_path.h"
#include "content/public/browser/access_token_store.h"
#include "content/public/browser/media_observer.h"
#include "content/public/browser/render_process_host.h"
#include "content/public/browser/resource_dispatcher_host.h"
#include "content/public/common/content_switches.h"
#include "googleurl/src/gurl.h"

namespace {

// In-memory store for access tokens used by geolocation.
class CefAccessTokenStore : public content::AccessTokenStore {
 public:
  CefAccessTokenStore() {}

  virtual void LoadAccessTokens(
      const LoadAccessTokensCallbackType& callback) OVERRIDE {
    callback.Run(access_token_set_,
        _Context->browser_context()->GetRequestContext());
  }

  virtual void SaveAccessToken(
      const GURL& server_url, const string16& access_token) OVERRIDE {
    access_token_set_[server_url] = access_token;
  }

 private:
  AccessTokenSet access_token_set_;
};

}  // namespace


class CefMediaObserver : public content::MediaObserver {
 public:
  CefMediaObserver() {}
  virtual ~CefMediaObserver() {}

  virtual void OnDeleteAudioStream(void* host, int stream_id) OVERRIDE {}

  virtual void OnSetAudioStreamPlaying(void* host, int stream_id,
                                       bool playing) OVERRIDE {}
  virtual void OnSetAudioStreamStatus(void* host, int stream_id,
                                      const std::string& status) OVERRIDE {}
  virtual void OnSetAudioStreamVolume(void* host, int stream_id,
                                      double volume) OVERRIDE {}
  virtual void OnMediaEvent(int render_process_id,
                            const media::MediaLogEvent& event) OVERRIDE {}
  virtual void OnCaptureDevicesOpened(
      int render_process_id,
      int render_view_id,
      const content::MediaStreamDevices& devices) OVERRIDE {}
  virtual void OnCaptureDevicesClosed(
      int render_process_id,
      int render_view_id,
      const content::MediaStreamDevices& devices) OVERRIDE {}
};


CefContentBrowserClient::CefContentBrowserClient()
    : browser_main_parts_(NULL) {
}

CefContentBrowserClient::~CefContentBrowserClient() {
}

content::BrowserMainParts* CefContentBrowserClient::CreateBrowserMainParts(
    const content::MainFunctionParams& parameters) {
  browser_main_parts_ = new CefBrowserMainParts(parameters);
  return browser_main_parts_;
}

void CefContentBrowserClient::RenderProcessHostCreated(
    content::RenderProcessHost* host) {
  host->GetChannel()->AddFilter(new CefBrowserMessageFilter(host));
}

void CefContentBrowserClient::AppendExtraCommandLineSwitches(
    CommandLine* command_line, int child_process_id) {
  std::string process_type =
      command_line->GetSwitchValueASCII(switches::kProcessType);
  if (process_type == switches::kRendererProcess) {
      // Propagate the following switches to the renderer command line (along
      // with any associated values) if present in the browser command line.
      static const char* const kSwitchNames[] = {
        switches::kLogFile,
        switches::kLogSeverity,
        switches::kProductVersion,
        switches::kLocale,
        switches::kPackFilePath,
        switches::kLocalesDirPath,
        switches::kPackLoadingDisabled,
      };
      const CommandLine& browser_cmd = *CommandLine::ForCurrentProcess();
      command_line->CopySwitchesFrom(browser_cmd, kSwitchNames,
                                     arraysize(kSwitchNames));
  }
}

content::MediaObserver* CefContentBrowserClient::GetMediaObserver() {
  // TODO(cef): Return NULL once it's supported. See crbug.com/116113.
  if (!media_observer_.get())
     media_observer_.reset(new CefMediaObserver());
  return media_observer_.get();
}

content::AccessTokenStore* CefContentBrowserClient::CreateAccessTokenStore() {
  return new CefAccessTokenStore;
}

void CefContentBrowserClient::ResourceDispatcherHostCreated() {
  resource_dispatcher_host_delegate_.reset(
      new CefResourceDispatcherHostDelegate());
  content::ResourceDispatcherHost::Get()->SetDelegate(
      resource_dispatcher_host_delegate_.get());
}

void CefContentBrowserClient::OverrideWebkitPrefs(
    content::RenderViewHost* rvh,
    const GURL& url,
    webkit_glue::WebPreferences* prefs) {
  CefRefPtr<CefBrowserHostImpl> browser =
      CefBrowserHostImpl::GetBrowserForHost(rvh);
  DCHECK(browser.get());

  // Populate WebPreferences based on CefBrowserSettings.
  BrowserToWebSettings(browser->settings(), *prefs);
}

std::string CefContentBrowserClient::GetDefaultDownloadName() {
  return "download";
}
