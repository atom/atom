// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <map>
#include "include/internal/cef_string_map.h"
#include "base/logging.h"

typedef std::map<CefString, CefString> StringMap;

CEF_EXPORT cef_string_map_t cef_string_map_alloc() {
  return new StringMap;
}

CEF_EXPORT int cef_string_map_size(cef_string_map_t map) {
  DCHECK(map);
  StringMap* impl = reinterpret_cast<StringMap*>(map);
  return impl->size();
}

CEF_EXPORT int cef_string_map_find(cef_string_map_t map,
                                   const cef_string_t* key,
                                   cef_string_t* value) {
  DCHECK(map);
  DCHECK(value);
  StringMap* impl = reinterpret_cast<StringMap*>(map);
  StringMap::const_iterator it = impl->find(CefString(key));
  if (it == impl->end())
    return 0;

  const CefString& val = it->second;
  return cef_string_set(val.c_str(), val.length(), value, true);
}

CEF_EXPORT int cef_string_map_key(cef_string_map_t map, int index,
                                  cef_string_t* key) {
  DCHECK(map);
  DCHECK(key);
  StringMap* impl = reinterpret_cast<StringMap*>(map);
  DCHECK_GE(index, 0);
  DCHECK_LT(index, static_cast<int>(impl->size()));
  if (index < 0 || index >= static_cast<int>(impl->size()))
    return 0;

  StringMap::const_iterator it = impl->begin();
  for (int ct = 0; it != impl->end(); ++it, ct++) {
    if (ct == index)
      return cef_string_set(it->first.c_str(), it->first.length(), key, true);
  }
  return 0;
}

CEF_EXPORT int cef_string_map_value(cef_string_map_t map, int index,
                                    cef_string_t* value) {
  DCHECK(map);
  DCHECK(value);
  StringMap* impl = reinterpret_cast<StringMap*>(map);
  DCHECK_GE(index, 0);
  DCHECK_LT(index, static_cast<int>(impl->size()));
  if (index < 0 || index >= static_cast<int>(impl->size()))
    return 0;

  StringMap::const_iterator it = impl->begin();
  for (int ct = 0; it != impl->end(); ++it, ct++) {
    if (ct == index) {
      return cef_string_set(it->second.c_str(), it->second.length(), value,
          true);
    }
  }
  return 0;
}

CEF_EXPORT int cef_string_map_append(cef_string_map_t map,
                                     const cef_string_t* key,
                                     const cef_string_t* value) {
  DCHECK(map);
  StringMap* impl = reinterpret_cast<StringMap*>(map);
  impl->insert(std::make_pair(CefString(key), CefString(value)));
  return 1;
}

CEF_EXPORT void cef_string_map_clear(cef_string_map_t map) {
  DCHECK(map);
  StringMap* impl = reinterpret_cast<StringMap*>(map);
  impl->clear();
}

CEF_EXPORT void cef_string_map_free(cef_string_map_t map) {
  DCHECK(map);
  StringMap* impl = reinterpret_cast<StringMap*>(map);
  delete impl;
}
