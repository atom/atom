// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/cookie_manager_impl.h"

#include <string>

#include "libcef/browser/browser_context.h"
#include "libcef/browser/context.h"
#include "libcef/browser/thread_util.h"
#include "libcef/browser/url_request_context_getter.h"
#include "libcef/common/time_util.h"

#include "base/bind.h"
#include "base/file_util.h"
#include "base/format_macros.h"
#include "base/logging.h"
#include "base/threading/thread_restrictions.h"
#include "chrome/browser/net/sqlite_persistent_cookie_store.h"
#include "googleurl/src/gurl.h"
#include "net/cookies/cookie_util.h"
#include "net/url_request/url_request_context.h"

namespace {

// Callback class for visiting cookies.
class VisitCookiesCallback : public base::RefCounted<VisitCookiesCallback> {
 public:
  explicit VisitCookiesCallback(net::CookieMonster* cookie_monster,
                                CefRefPtr<CefCookieVisitor> visitor)
    : cookie_monster_(cookie_monster),
      visitor_(visitor) {
  }

  void Run(const net::CookieList& list) {
    CEF_REQUIRE_IOT();

    int total = list.size(), count = 0;

    net::CookieList::const_iterator it = list.begin();
    for (; it != list.end(); ++it, ++count) {
      CefCookie cookie;
      const net::CookieMonster::CanonicalCookie& cc = *(it);
      CefCookieManagerImpl::GetCefCookie(cc, cookie);

      bool deleteCookie = false;
      bool keepLooping = visitor_->Visit(cookie, count, total, deleteCookie);
      if (deleteCookie) {
        cookie_monster_->DeleteCanonicalCookieAsync(cc,
            net::CookieMonster::DeleteCookieCallback());
      }
      if (!keepLooping)
        break;
    }
  }

 private:
  scoped_refptr<net::CookieMonster> cookie_monster_;
  CefRefPtr<CefCookieVisitor> visitor_;
};


// Methods extracted from net/cookies/cookie_monster.cc

// Determine the cookie domain to use for setting the specified cookie.
bool GetCookieDomain(const GURL& url,
                     const net::CookieMonster::ParsedCookie& pc,
                     std::string* result) {
  std::string domain_string;
  if (pc.HasDomain())
    domain_string = pc.Domain();
  return net::cookie_util::GetCookieDomainWithString(url, domain_string,
      result);
}

std::string CanonPathWithString(const GURL& url,
                                const std::string& path_string) {
  // The RFC says the path should be a prefix of the current URL path.
  // However, Mozilla allows you to set any path for compatibility with
  // broken websites.  We unfortunately will mimic this behavior.  We try
  // to be generous and accept cookies with an invalid path attribute, and
  // default the path to something reasonable.

  // The path was supplied in the cookie, we'll take it.
  if (!path_string.empty() && path_string[0] == '/')
    return path_string;

  // The path was not supplied in the cookie or invalid, we will default
  // to the current URL path.
  // """Defaults to the path of the request URL that generated the
  //    Set-Cookie response, up to, but not including, the
  //    right-most /."""
  // How would this work for a cookie on /?  We will include it then.
  const std::string& url_path = url.path();

  size_t idx = url_path.find_last_of('/');

  // The cookie path was invalid or a single '/'.
  if (idx == 0 || idx == std::string::npos)
    return std::string("/");

  // Return up to the rightmost '/'.
  return url_path.substr(0, idx);
}

std::string CanonPath(const GURL& url,
                      const net::CookieMonster::ParsedCookie& pc) {
  std::string path_string;
  if (pc.HasPath())
    path_string = pc.Path();
  return CanonPathWithString(url, path_string);
}

base::Time CanonExpiration(const net::CookieMonster::ParsedCookie& pc,
                           const base::Time& current) {
  // First, try the Max-Age attribute.
  uint64 max_age = 0;
  if (pc.HasMaxAge() &&
#ifdef COMPILER_MSVC
      sscanf_s(
#else
      sscanf(
#endif
             pc.MaxAge().c_str(), " %" PRIu64, &max_age) == 1) {
    return current + base::TimeDelta::FromSeconds(max_age);
  }

  // Try the Expires attribute.
  if (pc.HasExpires())
    return net::CookieMonster::ParseCookieTime(pc.Expires());

  // Invalid or no expiration, persistent cookie.
  return base::Time();
}

}  // namespace


CefCookieManagerImpl::CefCookieManagerImpl(bool is_global)
  : is_global_(is_global) {
}

CefCookieManagerImpl::~CefCookieManagerImpl() {
}

void CefCookieManagerImpl::Initialize(const CefString& path) {
  if (is_global_)
    SetGlobal();
  else
    SetStoragePath(path);
}

void CefCookieManagerImpl::SetSupportedSchemes(
    const std::vector<CefString>& schemes) {
  if (CEF_CURRENTLY_ON_IOT()) {
    if (!cookie_monster_)
      return;

    if (is_global_) {
      // Global changes are handled by the request context.
      CefURLRequestContextGetter* getter =
          static_cast<CefURLRequestContextGetter*>(
              _Context->browser_context()->GetRequestContext());

      std::vector<std::string> scheme_vec;
      std::vector<CefString>::const_iterator it = schemes.begin();
      for (; it != schemes.end(); ++it)
        scheme_vec.push_back(it->ToString());

      getter->SetCookieSupportedSchemes(scheme_vec);
      return;
    }

    supported_schemes_ = schemes;

    if (supported_schemes_.empty()) {
      supported_schemes_.push_back("http");
      supported_schemes_.push_back("https");
    }

    std::set<std::string> scheme_set;
    std::vector<CefString>::const_iterator it = supported_schemes_.begin();
    for (; it != supported_schemes_.end(); ++it)
      scheme_set.insert(*it);

    const char** arr = new const char*[scheme_set.size()];
    std::set<std::string>::const_iterator it2 = scheme_set.begin();
    for (int i = 0; it2 != scheme_set.end(); ++it2, ++i)
      arr[i] = it2->c_str();

    cookie_monster_->SetCookieableSchemes(arr, scheme_set.size());

    delete [] arr;
  } else {
    // Execute on the IO thread.
    CEF_POST_TASK(CEF_IOT,
        base::Bind(&CefCookieManagerImpl::SetSupportedSchemes,
                   this, schemes));
  }
}

bool CefCookieManagerImpl::VisitAllCookies(
    CefRefPtr<CefCookieVisitor> visitor) {
  if (CEF_CURRENTLY_ON_IOT()) {
    if (!cookie_monster_)
      return false;

    scoped_refptr<VisitCookiesCallback> callback(
      new VisitCookiesCallback(cookie_monster_, visitor));

    cookie_monster_->GetAllCookiesAsync(
        base::Bind(&VisitCookiesCallback::Run, callback.get()));
  } else {
    // Execute on the IO thread.
    CEF_POST_TASK(CEF_IOT,
        base::Bind(base::IgnoreResult(&CefCookieManagerImpl::VisitAllCookies),
                   this, visitor));
  }

  return true;
}

bool CefCookieManagerImpl::VisitUrlCookies(
    const CefString& url, bool includeHttpOnly,
    CefRefPtr<CefCookieVisitor> visitor) {
  if (CEF_CURRENTLY_ON_IOT()) {
    if (!cookie_monster_)
      return false;

    net::CookieOptions options;
    if (includeHttpOnly)
      options.set_include_httponly();

    scoped_refptr<VisitCookiesCallback> callback(
        new VisitCookiesCallback(cookie_monster_, visitor));

    GURL gurl = GURL(url.ToString());
    cookie_monster_->GetAllCookiesForURLWithOptionsAsync(gurl, options,
        base::Bind(&VisitCookiesCallback::Run, callback.get()));
  } else {
    // Execute on the IO thread.
    CEF_POST_TASK(CEF_IOT,
        base::Bind(base::IgnoreResult(&CefCookieManagerImpl::VisitUrlCookies),
                   this, url, includeHttpOnly, visitor));
  }

  return true;
}

bool CefCookieManagerImpl::SetCookie(const CefString& url,
                                     const CefCookie& cookie) {
  CEF_REQUIRE_IOT_RETURN(false);

  if (!cookie_monster_)
    return false;

  GURL gurl = GURL(url.ToString());
  if (!gurl.is_valid())
    return false;

  std::string name = CefString(&cookie.name).ToString();
  std::string value = CefString(&cookie.value).ToString();
  std::string domain = CefString(&cookie.domain).ToString();
  std::string path = CefString(&cookie.path).ToString();

  base::Time expiration_time;
  if (cookie.has_expires)
    cef_time_to_basetime(cookie.expires, expiration_time);

  cookie_monster_->SetCookieWithDetailsAsync(gurl, name, value, domain, path,
      expiration_time, cookie.secure, cookie.httponly,
      net::CookieStore::SetCookiesCallback());
  return true;
}

bool CefCookieManagerImpl::DeleteCookies(const CefString& url,
                                         const CefString& cookie_name) {
  CEF_REQUIRE_IOT_RETURN(false);

  if (!cookie_monster_)
    return false;

  if (url.empty()) {
    // Delete all cookies.
    cookie_monster_->DeleteAllAsync(net::CookieMonster::DeleteCallback());
    return true;
  }

  GURL gurl = GURL(url.ToString());
  if (!gurl.is_valid())
    return false;

  if (cookie_name.empty()) {
    // Delete all matching host cookies.
    cookie_monster_->DeleteAllForHostAsync(gurl,
        net::CookieMonster::DeleteCallback());
  } else {
    // Delete all matching host and domain cookies.
    cookie_monster_->DeleteCookieAsync(gurl, cookie_name, base::Closure());
  }
  return true;
}

bool CefCookieManagerImpl::SetStoragePath(const CefString& path) {
  if (CEF_CURRENTLY_ON_IOT()) {
    FilePath new_path;
    if (!path.empty())
      new_path = FilePath(path);

    if (is_global_) {
      // Global path changes are handled by the request context.
      CefURLRequestContextGetter* getter =
          static_cast<CefURLRequestContextGetter*>(
              _Context->browser_context()->GetRequestContext());
      getter->SetCookieStoragePath(new_path);
      cookie_monster_ = getter->GetURLRequestContext()->cookie_store()->
          GetCookieMonster();
      return true;
    }
    
    if (cookie_monster_ && ((storage_path_.empty() && path.empty()) ||
                            storage_path_ == new_path)) {
      // The path has not changed so don't do anything.
      return true;
    }

    scoped_refptr<SQLitePersistentCookieStore> persistent_store;
    if (!new_path.empty()) {
      // TODO(cef): Move directory creation to the blocking pool instead of
      // allowing file IO on this thread.
      base::ThreadRestrictions::ScopedAllowIO allow_io;
      if (file_util::DirectoryExists(new_path) ||
          file_util::CreateDirectory(new_path)) {
        const FilePath& cookie_path = new_path.AppendASCII("Cookies");
        persistent_store =
            new SQLitePersistentCookieStore(cookie_path, false, NULL);
      } else {
        NOTREACHED() << "The cookie storage directory could not be created";
        storage_path_.clear();
      }
    }

    // Set the new cookie store that will be used for all new requests. The old
    // cookie store, if any, will be automatically flushed and closed when no
    // longer referenced.
    cookie_monster_ = new net::CookieMonster(persistent_store.get(), NULL);
    storage_path_ = new_path;

    // Restore the previously supported schemes.
    SetSupportedSchemes(supported_schemes_);
  } else {
    // Execute on the IO thread.
    CEF_POST_TASK(CEF_IOT,
        base::Bind(base::IgnoreResult(&CefCookieManagerImpl::SetStoragePath),
                   this, path));
  }

  return true;
}

void CefCookieManagerImpl::SetGlobal() {
  if (CEF_CURRENTLY_ON_IOT()) {
    if (_Context->browser_context()) {
      cookie_monster_ = _Context->browser_context()->GetRequestContext()->
          GetURLRequestContext()->cookie_store()->GetCookieMonster();
      DCHECK(cookie_monster_);
    }
  } else {
    // Execute on the IO thread.
    CEF_POST_TASK(CEF_IOT, base::Bind(&CefCookieManagerImpl::SetGlobal, this));
  }
}

// static
bool CefCookieManagerImpl::GetCefCookie(
    const net::CookieMonster::CanonicalCookie& cc,
    CefCookie& cookie) {
  CefString(&cookie.name).FromString(cc.Name());
  CefString(&cookie.value).FromString(cc.Value());
  CefString(&cookie.domain).FromString(cc.Domain());
  CefString(&cookie.path).FromString(cc.Path());
  cookie.secure = cc.IsSecure();
  cookie.httponly = cc.IsHttpOnly();
  cef_time_from_basetime(cc.CreationDate(), cookie.creation);
  cef_time_from_basetime(cc.LastAccessDate(), cookie.last_access);
  cookie.has_expires = cc.DoesExpire();
  if (cookie.has_expires)
    cef_time_from_basetime(cc.ExpiryDate(), cookie.expires);

  return true;
}

// static
bool CefCookieManagerImpl::GetCefCookie(const GURL& url,
                                        const std::string& cookie_line,
                                        CefCookie& cookie) {
  // Parse the cookie.
  net::CookieMonster::ParsedCookie pc(cookie_line);
  if (!pc.IsValid())
    return false;

  std::string cookie_domain;
  if (!GetCookieDomain(url, pc, &cookie_domain))
    return false;

  std::string cookie_path = CanonPath(url, pc);
  base::Time creation_time = base::Time::Now();
  base::Time cookie_expires = CanonExpiration(pc, creation_time);

  CefString(&cookie.name).FromString(pc.Name());
  CefString(&cookie.value).FromString(pc.Value());
  CefString(&cookie.domain).FromString(cookie_domain);
  CefString(&cookie.path).FromString(cookie_path);
  cookie.secure = pc.IsSecure();
  cookie.httponly = pc.IsHttpOnly();
  cef_time_from_basetime(creation_time, cookie.creation);
  cef_time_from_basetime(creation_time, cookie.last_access);
  cookie.has_expires = !cookie_expires.is_null();
  if (cookie.has_expires)
    cef_time_from_basetime(cookie_expires, cookie.expires);

  return true;
}


// CefCookieManager methods ----------------------------------------------------

// static
CefRefPtr<CefCookieManager> CefCookieManager::GetGlobalManager() {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return NULL;
  }

  CefRefPtr<CefCookieManagerImpl> manager(new CefCookieManagerImpl(true));
  manager->Initialize(CefString());
  return manager.get();
}

// static
CefRefPtr<CefCookieManager> CefCookieManager::CreateManager(
    const CefString& path) {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return NULL;
  }

  CefRefPtr<CefCookieManagerImpl> manager(new CefCookieManagerImpl(false));
  manager->Initialize(path);
  return manager.get();
}
