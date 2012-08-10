// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_HTTP_HEADER_UTILS_H_
#define CEF_LIBCEF_COMMON_HTTP_HEADER_UTILS_H_
#pragma once

#include <string>

#include "include/cef_request.h"

namespace HttpHeaderUtils {

typedef CefRequest::HeaderMap HeaderMap;

std::string GenerateHeaders(const HeaderMap& map);
void ParseHeaders(const std::string& header_str, HeaderMap& map);

};  // namespace HttpHeaderUtils

#endif  // CEF_LIBCEF_COMMON_HTTP_HEADER_UTILS_H_
