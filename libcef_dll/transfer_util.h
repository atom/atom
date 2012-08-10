// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_DLL_TRANSFER_UTIL_H_
#define CEF_LIBCEF_DLL_TRANSFER_UTIL_H_
#pragma once

#include <map>
#include <vector>

#include "include/internal/cef_string_list.h"
#include "include/internal/cef_string_map.h"
#include "include/internal/cef_string_multimap.h"

// Copy contents from one list type to another.
typedef std::vector<CefString> StringList;
void transfer_string_list_contents(cef_string_list_t fromList,
                                   StringList& toList);
void transfer_string_list_contents(const StringList& fromList,
                                   cef_string_list_t toList);

// Copy contents from one map type to another.
typedef std::map<CefString, CefString> StringMap;
void transfer_string_map_contents(cef_string_map_t fromMap,
                                  StringMap& toMap);
void transfer_string_map_contents(const StringMap& fromMap,
                                  cef_string_map_t toMap);

// Copy contents from one map type to another.
typedef std::multimap<CefString, CefString> StringMultimap;
void transfer_string_multimap_contents(cef_string_multimap_t fromMap,
                                       StringMultimap& toMap);
void transfer_string_multimap_contents(const StringMultimap& fromMap,
                                       cef_string_multimap_t toMap);

#endif  // CEF_LIBCEF_DLL_TRANSFER_UTIL_H_
