// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_RESOURCE_UTIL_H_
#define CEF_TESTS_CEFCLIENT_RESOURCE_UTIL_H_
#pragma once

#include "include/cef_base.h"

class CefStreamReader;

#if defined(OS_WIN)

#include "cefclient/resource.h"

// Load a resource of type BINARY
bool LoadBinaryResource(int binaryId, DWORD &dwSize, LPBYTE &pBytes);
CefRefPtr<CefStreamReader> GetBinaryResourceReader(int binaryId);

#elif defined(OS_MACOSX) || defined(OS_POSIX)

#include <string>  // NOLINT(build/include_order)

// Load the resource with the specified name.
bool LoadBinaryResource(const char* resource_name, std::string& resource_data);

#endif

CefRefPtr<CefStreamReader> GetBinaryResourceReader(const char* resource_name);

#endif  // CEF_TESTS_CEFCLIENT_RESOURCE_UTIL_H_
