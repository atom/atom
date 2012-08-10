// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_web_plugin.h"
#include "libcef/browser/context.h"
#include "libcef/browser/thread_util.h"

#include "base/bind.h"
#include "base/file_path.h"
#include "content/browser/plugin_service_impl.h"

namespace {

class CefWebPluginInfoImpl : public CefWebPluginInfo {
 public:
  explicit CefWebPluginInfoImpl(const webkit::WebPluginInfo& plugin_info)
      : plugin_info_(plugin_info) {
  }

  virtual CefString GetName() OVERRIDE {
    return plugin_info_.name;
  }

  virtual CefString GetPath() OVERRIDE {
    return plugin_info_.path.value();
  }

  virtual CefString GetVersion() OVERRIDE {
    return plugin_info_.version;
  }

  virtual CefString GetDescription() OVERRIDE {
    return plugin_info_.desc;
  }

 private:
  webkit::WebPluginInfo plugin_info_;

  IMPLEMENT_REFCOUNTING(CefWebPluginInfoImpl);
};

void PluginsCallbackImpl(
    CefRefPtr<CefWebPluginInfoVisitor> visitor,
    const std::vector<webkit::WebPluginInfo>& all_plugins) {
  CEF_REQUIRE_UIT();

  int count = 0;
  int total = static_cast<int>(all_plugins.size());

  std::vector<webkit::WebPluginInfo>::const_iterator it = all_plugins.begin();
  for (; it != all_plugins.end(); ++it, ++count) {
    CefRefPtr<CefWebPluginInfoImpl> info(new CefWebPluginInfoImpl(*it));
    if (!visitor->Visit(info.get(), count, total))
      break;
  }
}

}  // namespace

void CefVisitWebPluginInfo(CefRefPtr<CefWebPluginInfoVisitor> visitor) {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return;
  }

  if (CEF_CURRENTLY_ON_UIT()) {
    PluginServiceImpl::GetInstance()->GetPlugins(
        base::Bind(PluginsCallbackImpl, visitor));
  } else {
    // Execute on the UI thread.
    CEF_POST_TASK(CEF_UIT, base::Bind(CefVisitWebPluginInfo, visitor));
  }
}
