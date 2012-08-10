// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/browser/origin_whitelist_impl.h"

#include <string>
#include <list>

#include "include/cef_origin_whitelist.h"
#include "libcef/browser/context.h"
#include "libcef/browser/thread_util.h"
#include "libcef/common/cef_messages.h"

#include "base/bind.h"
#include "base/lazy_instance.h"
#include "content/public/browser/render_process_host.h"
#include "googleurl/src/gurl.h"

namespace {

// Class that manages cross-origin whitelist registrations.
class CefOriginWhitelistManager {
 public:
  CefOriginWhitelistManager() {}

  // Retrieve the singleton instance.
  static CefOriginWhitelistManager* GetInstance();

  bool AddOriginEntry(const std::string& source_origin,
                      const std::string& target_protocol,
                      const std::string& target_domain,
                      bool allow_target_subdomains) {
    CEF_REQUIRE_UIT();

    OriginInfo info;
    info.source_origin = source_origin;
    info.target_protocol = target_protocol;
    info.target_domain = target_domain;
    info.allow_target_subdomains = allow_target_subdomains;

    // Verify that the origin entry doesn't already exist.
    OriginList::const_iterator it = origin_list_.begin();
    for (; it != origin_list_.end(); ++it) {
      if (it->Equals(info))
        return false;
    }

    origin_list_.push_back(info);

    SendModifyCrossOriginWhitelistEntry(true, source_origin, target_protocol,
        target_domain, allow_target_subdomains);
    return true;
  }

  bool RemoveOriginEntry(const std::string& source_origin,
                         const std::string& target_protocol,
                         const std::string& target_domain,
                         bool allow_target_subdomains) {
    CEF_REQUIRE_UIT();

    OriginInfo info;
    info.source_origin = source_origin;
    info.target_protocol = target_protocol;
    info.target_domain = target_domain;
    info.allow_target_subdomains = allow_target_subdomains;

    bool found = false;

    OriginList::iterator it = origin_list_.begin();
    for (; it != origin_list_.end(); ++it) {
      if (it->Equals(info)) {
        origin_list_.erase(it);
        found = true;
        break;
      }
    }

    if (!found)
      return false;

    SendModifyCrossOriginWhitelistEntry(false, source_origin, target_protocol,
        target_domain, allow_target_subdomains);
    return true;
  }

  void ClearOrigins() {
    CEF_REQUIRE_UIT();

    origin_list_.clear();

    SendClearCrossOriginWhitelist();
  }

  // Send all existing cross-origin registrations to the specified host.
  void RegisterOriginsWithHost(content::RenderProcessHost* host) {
    CEF_REQUIRE_UIT();

    if (origin_list_.empty())
      return;

    OriginList::const_iterator it = origin_list_.begin();
    for (; it != origin_list_.end(); ++it) {
      host->Send(
          new CefProcessMsg_ModifyCrossOriginWhitelistEntry(
              true, it->source_origin, it->target_protocol, it->target_domain,
              it->allow_target_subdomains));
    }
  }

 private:
  // Send the modify cross-origin whitelist entry message to all currently
  // existing hosts.
  void SendModifyCrossOriginWhitelistEntry(bool add,
                                           const std::string& source_origin,
                                           const std::string& target_protocol,
                                           const std::string& target_domain,
                                           bool allow_target_subdomains) {
    CEF_REQUIRE_UIT();

    content::RenderProcessHost::iterator i(
        content::RenderProcessHost::AllHostsIterator());
    for (; !i.IsAtEnd(); i.Advance()) {
      i.GetCurrentValue()->Send(
          new CefProcessMsg_ModifyCrossOriginWhitelistEntry(
              add, source_origin, target_protocol, target_domain,
              allow_target_subdomains));
    }
  }

  // Send the clear cross-origin whitelists message to all currently existing
  // hosts.
  void SendClearCrossOriginWhitelist() {
    CEF_REQUIRE_UIT();

    content::RenderProcessHost::iterator i(
        content::RenderProcessHost::AllHostsIterator());
    for (; !i.IsAtEnd(); i.Advance()) {
      i.GetCurrentValue()->Send(new CefProcessMsg_ClearCrossOriginWhitelist);
    }
  }

  struct OriginInfo {
    std::string source_origin;
    std::string target_protocol;
    std::string target_domain;
    bool allow_target_subdomains;

    bool Equals(const OriginInfo& info) const {
      return (source_origin == info.source_origin &&
              target_protocol == info.target_protocol &&
              target_domain == info.target_domain &&
              allow_target_subdomains == info.allow_target_subdomains);
    }
  };

  // List of registered origins.
  typedef std::list<OriginInfo> OriginList;
  OriginList origin_list_;

  DISALLOW_EVIL_CONSTRUCTORS(CefOriginWhitelistManager);
};

base::LazyInstance<CefOriginWhitelistManager> g_manager =
    LAZY_INSTANCE_INITIALIZER;

CefOriginWhitelistManager* CefOriginWhitelistManager::GetInstance() {
  return g_manager.Pointer();
}

}  // namespace

bool CefAddCrossOriginWhitelistEntry(const CefString& source_origin,
                                     const CefString& target_protocol,
                                     const CefString& target_domain,
                                     bool allow_target_subdomains) {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED();
    return false;
  }

  std::string source_url = source_origin;
  GURL gurl = GURL(source_url);
  if (gurl.is_empty() || !gurl.is_valid()) {
    NOTREACHED() << "Invalid source_origin URL: " << source_url;
    return false;
  }

  if (CEF_CURRENTLY_ON_UIT()) {
    return CefOriginWhitelistManager::GetInstance()->AddOriginEntry(
        source_origin, target_protocol, target_domain, allow_target_subdomains);
  } else {
    CEF_POST_TASK(CEF_UIT,
        base::Bind(base::IgnoreResult(&CefAddCrossOriginWhitelistEntry),
                   source_origin, target_protocol, target_domain,
                   allow_target_subdomains));
  }

  return true;
}

bool CefRemoveCrossOriginWhitelistEntry(const CefString& source_origin,
                                        const CefString& target_protocol,
                                        const CefString& target_domain,
                                        bool allow_target_subdomains) {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED();
    return false;
  }

  std::string source_url = source_origin;
  GURL gurl = GURL(source_url);
  if (gurl.is_empty() || !gurl.is_valid()) {
    NOTREACHED() << "Invalid source_origin URL: " << source_url;
    return false;
  }

  if (CEF_CURRENTLY_ON_UIT()) {
    return CefOriginWhitelistManager::GetInstance()->RemoveOriginEntry(
        source_origin, target_protocol, target_domain, allow_target_subdomains);
  } else {
    CEF_POST_TASK(CEF_UIT,
        base::Bind(base::IgnoreResult(&CefRemoveCrossOriginWhitelistEntry),
                   source_origin, target_protocol, target_domain,
                   allow_target_subdomains));
  }

  return true;
}

bool CefClearCrossOriginWhitelist() {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED();
    return false;
  }

  if (CEF_CURRENTLY_ON_UIT()) {
    CefOriginWhitelistManager::GetInstance()->ClearOrigins();
  } else {
    CEF_POST_TASK(CEF_UIT,
        base::Bind(base::IgnoreResult(&CefClearCrossOriginWhitelist)));
  }

  return true;
}

void RegisterCrossOriginWhitelistEntriesWithHost(
    content::RenderProcessHost* host) {
  CEF_REQUIRE_UIT();
  CefOriginWhitelistManager::GetInstance()->RegisterOriginsWithHost(host);
}
