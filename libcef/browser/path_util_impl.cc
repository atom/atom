// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_path_util.h"

#include "base/file_path.h"
#include "base/logging.h"
#include "base/path_service.h"

bool CefGetPath(PathKey key, CefString& path) {
  int pref_key = base::PATH_START;
  switch(key) {
    case PK_DIR_CURRENT:
      pref_key = base::DIR_CURRENT;
      break;
    case PK_DIR_EXE:
      pref_key = base::DIR_EXE;
      break;
    case PK_DIR_MODULE:
      pref_key = base::DIR_MODULE;
      break;
    case PK_DIR_TEMP:
      pref_key = base::DIR_TEMP;
      break;
    case PK_FILE_EXE:
      pref_key = base::FILE_EXE;
      break;
    case PK_FILE_MODULE:
      pref_key = base::FILE_MODULE;
      break;
    default:
      NOTREACHED() << "invalid argument";
      return false;
  }

  FilePath file_path;
  if (PathService::Get(pref_key, &file_path)) {
    path = file_path.value();
    return true;
  }

  return false;
}
