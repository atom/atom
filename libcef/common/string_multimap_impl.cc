// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <map>
#include "include/internal/cef_string_multimap.h"
#include "base/logging.h"

typedef std::multimap<CefString, CefString> StringMultimap;

CEF_EXPORT cef_string_multimap_t cef_string_multimap_alloc() {
  return new StringMultimap;
}

CEF_EXPORT int cef_string_multimap_size(cef_string_multimap_t map) {
  DCHECK(map);
  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  return impl->size();
}

CEF_EXPORT int cef_string_multimap_find_count(cef_string_multimap_t map,
                                              const cef_string_t* key) {
  DCHECK(map);
  DCHECK(key);
  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  return impl->count(CefString(key));
}

CEF_EXPORT int cef_string_multimap_enumerate(cef_string_multimap_t map,
                                             const cef_string_t* key,
                                             int value_index,
                                             cef_string_t* value) {
  DCHECK(map);
  DCHECK(key);
  DCHECK(value);

  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  CefString key_str(key);

  DCHECK_GE(value_index, 0);
  DCHECK_LT(value_index, static_cast<int>(impl->count(key_str)));
  if (value_index < 0 || value_index >= static_cast<int>(impl->count(key_str)))
    return 0;

  std::pair<StringMultimap::iterator, StringMultimap::iterator> range_it =
      impl->equal_range(key_str);

  int count = value_index;
  while (count-- && range_it.first != range_it.second)
    range_it.first++;

  if (range_it.first == range_it.second)
    return 0;

  const CefString& val = range_it.first->second;
  return cef_string_set(val.c_str(), val.length(), value, true);
}

CEF_EXPORT int cef_string_multimap_key(cef_string_multimap_t map, int index,
                                       cef_string_t* key) {
  DCHECK(map);
  DCHECK(key);
  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  DCHECK_GE(index, 0);
  DCHECK_LT(index, static_cast<int>(impl->size()));
  if (index < 0 || index >= static_cast<int>(impl->size()))
    return 0;

  StringMultimap::const_iterator it = impl->begin();
  for (int ct = 0; it != impl->end(); ++it, ct++) {
    if (ct == index)
      return cef_string_set(it->first.c_str(), it->first.length(), key, true);
  }
  return 0;
}

CEF_EXPORT int cef_string_multimap_value(cef_string_multimap_t map, int index,
                                         cef_string_t* value) {
  DCHECK(map);
  DCHECK(value);
  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  DCHECK_GE(index, 0);
  DCHECK_LT(index, static_cast<int>(impl->size()));
  if (index < 0 || index >= static_cast<int>(impl->size()))
    return 0;

  StringMultimap::const_iterator it = impl->begin();
  for (int ct = 0; it != impl->end(); ++it, ct++) {
    if (ct == index) {
      return cef_string_set(it->second.c_str(), it->second.length(), value,
          true);
    }
  }
  return 0;
}

CEF_EXPORT int cef_string_multimap_append(cef_string_multimap_t map,
                                          const cef_string_t* key,
                                          const cef_string_t* value) {
  DCHECK(map);
  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  impl->insert(std::make_pair(CefString(key), CefString(value)));
  return 1;
}

CEF_EXPORT void cef_string_multimap_clear(cef_string_multimap_t map) {
  DCHECK(map);
  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  impl->clear();
}

CEF_EXPORT void cef_string_multimap_free(cef_string_multimap_t map) {
  DCHECK(map);
  StringMultimap* impl = reinterpret_cast<StringMultimap*>(map);
  delete impl;
}
