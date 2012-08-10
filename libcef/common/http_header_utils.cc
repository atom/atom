// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/common/http_header_utils.h"
#include "net/http/http_response_headers.h"
#include "net/http/http_util.h"

using net::HttpResponseHeaders;

namespace HttpHeaderUtils {

std::string GenerateHeaders(const HeaderMap& map) {
  std::string headers;

  for (HeaderMap::const_iterator header = map.begin();
       header != map.end();
       ++header) {
    const CefString& key = header->first;
    const CefString& value = header->second;

    if (!key.empty()) {
      // Delimit with "\r\n".
      if (!headers.empty())
        headers += "\r\n";

      headers += std::string(key) + ": " + std::string(value);
    }
  }

  return headers;
}

void ParseHeaders(const std::string& header_str, HeaderMap& map) {
  // Parse the request header values
  for (net::HttpUtil::HeadersIterator i(header_str.begin(),
                                        header_str.end(), "\n");
       i.GetNext(); ) {
    map.insert(std::make_pair(i.name(), i.values()));
  }
}

}  // namespace HttpHeaderUtils
