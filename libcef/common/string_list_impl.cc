// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <vector>
#include "include/internal/cef_string_list.h"
#include "base/logging.h"

typedef std::vector<CefString> StringList;

CEF_EXPORT cef_string_list_t cef_string_list_alloc() {
  return new StringList;
}

CEF_EXPORT int cef_string_list_size(cef_string_list_t list) {
  DCHECK(list);
  StringList* impl = reinterpret_cast<StringList*>(list);
  return impl->size();
}

CEF_EXPORT int cef_string_list_value(cef_string_list_t list, int index,
                                     cef_string_t* value) {
  DCHECK(list);
  DCHECK(value);
  StringList* impl = reinterpret_cast<StringList*>(list);
  DCHECK_GE(index, 0);
  DCHECK_LT(index, static_cast<int>(impl->size()));
  if (index < 0 || index >= static_cast<int>(impl->size()))
    return false;
  const CefString& str = (*impl)[index];
  return cef_string_copy(str.c_str(), str.length(), value);
}

CEF_EXPORT void cef_string_list_append(cef_string_list_t list,
                                       const cef_string_t* value) {
  DCHECK(list);
  StringList* impl = reinterpret_cast<StringList*>(list);
  impl->push_back(CefString(value));
}

CEF_EXPORT void cef_string_list_clear(cef_string_list_t list) {
  DCHECK(list);
  StringList* impl = reinterpret_cast<StringList*>(list);
  impl->clear();
}

CEF_EXPORT void cef_string_list_free(cef_string_list_t list) {
  DCHECK(list);
  StringList* impl = reinterpret_cast<StringList*>(list);
  delete impl;
}

CEF_EXPORT cef_string_list_t cef_string_list_copy(cef_string_list_t list) {
  DCHECK(list);
  StringList* impl = reinterpret_cast<StringList*>(list);
  return new StringList(*impl);
}
