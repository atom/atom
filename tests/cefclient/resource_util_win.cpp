// Copyright (c) 2008-2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "cefclient/resource_util.h"
#include "include/cef_stream.h"
#include "include/wrapper/cef_byte_read_handler.h"
#include "cefclient/util.h"

#if defined(OS_WIN)

bool LoadBinaryResource(int binaryId, DWORD &dwSize, LPBYTE &pBytes) {
  extern HINSTANCE hInst;
  HRSRC hRes = FindResource(hInst, MAKEINTRESOURCE(binaryId),
                            MAKEINTRESOURCE(256));
  if (hRes) {
    HGLOBAL hGlob = LoadResource(hInst, hRes);
    if (hGlob) {
      dwSize = SizeofResource(hInst, hRes);
      pBytes = (LPBYTE)LockResource(hGlob);
      if (dwSize > 0 && pBytes)
        return true;
    }
  }

  return false;
}

CefRefPtr<CefStreamReader> GetBinaryResourceReader(int binaryId) {
  DWORD dwSize;
  LPBYTE pBytes;

  if (LoadBinaryResource(binaryId, dwSize, pBytes)) {
    return CefStreamReader::CreateForHandler(
        new CefByteReadHandler(pBytes, dwSize, NULL));
  }

  ASSERT(FALSE);  // The resource should be found.
  return NULL;
}

CefRefPtr<CefStreamReader> GetBinaryResourceReader(const char* resource_name) {
  // Map of resource labels to BINARY id values.
  static struct _resource_map {
    char* name;
    int id;
  } resource_map[] = {
    {"binding.html", IDS_BINDING},
    {"dialogs.html", IDS_DIALOGS},
    {"domaccess.html", IDS_DOMACCESS},
    {"localstorage.html", IDS_LOCALSTORAGE},
    {"xmlhttprequest.html", IDS_XMLHTTPREQUEST},
  };

  for (int i = 0; i < sizeof(resource_map)/sizeof(_resource_map); ++i) {
    if (!strcmp(resource_map[i].name, resource_name))
      return GetBinaryResourceReader(resource_map[i].id);
  }

  ASSERT(FALSE);  // The resource should be found.
  return NULL;
}

#endif  // OS_WIN
