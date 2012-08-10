// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include <sstream>
#include "include/cef_url.h"
#include "googleurl/src/gurl.h"

bool CefParseURL(const CefString& url,
                 CefURLParts& parts) {
  GURL gurl(url.ToString());
  if (!gurl.is_valid())
    return false;

  CefString(&parts.spec).FromString(gurl.spec());
  CefString(&parts.scheme).FromString(gurl.scheme());
  CefString(&parts.username).FromString(gurl.username());
  CefString(&parts.password).FromString(gurl.password());
  CefString(&parts.host).FromString(gurl.host());
  CefString(&parts.port).FromString(gurl.port());
  CefString(&parts.path).FromString(gurl.path());
  CefString(&parts.query).FromString(gurl.query());

  return true;
}

bool CefCreateURL(const CefURLParts& parts,
                  CefString& url) {
  std::string spec = CefString(parts.spec.str, parts.spec.length, false);
  std::string scheme = CefString(parts.scheme.str, parts.scheme.length, false);
  std::string username =
      CefString(parts.username.str, parts.username.length, false);
  std::string password =
      CefString(parts.password.str, parts.password.length, false);
  std::string host = CefString(parts.host.str, parts.host.length, false);
  std::string port = CefString(parts.port.str, parts.port.length, false);
  std::string path = CefString(parts.path.str, parts.path.length, false);
  std::string query = CefString(parts.query.str, parts.query.length, false);

  GURL gurl;
  if (!spec.empty()) {
    gurl = GURL(spec);
  } else if (!scheme.empty() && !host.empty()) {
    std::stringstream ss;
    ss << scheme << "://";
    if (!username.empty()) {
      ss << username;
      if (!password.empty())
        ss << ":" << password;
      ss << "@";
    }
    ss << host;
    if (!port.empty())
      ss << ":" << port;
    if (!path.empty())
      ss << path;
    if (!query.empty())
      ss << "?" << query;
    gurl = GURL(ss.str());
  }

  if (gurl.is_valid()) {
    url = gurl.spec();
    return true;
  }

  return false;
}
