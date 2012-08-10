// Copyright (c) 2011 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "cefclient/resource_util.h"
#include <stdio.h>
#include <string>
#include "include/cef_stream.h"
#include "cefclient/util.h"

bool GetResourceDir(std::string& dir) {
  char buff[1024];

  // Retrieve the executable path.
  ssize_t len = readlink("/proc/self/exe", buff, sizeof(buff)-1);
  if (len == -1)
    return false;

  buff[len] = 0;

  // Remove the executable name from the path.
  char* pos = strrchr(buff, '/');
  if (!pos)
    return false;

  // Add "files" to the path.
  strcpy(pos+1, "files");  // NOLINT(runtime/printf)
  dir = std::string(buff);
  return true;
}

bool LoadBinaryResource(const char* resource_name, std::string& resource_data) {
  std::string path;
  if (!GetResourceDir(path))
    return false;

  path.append("/");
  path.append(resource_name);

  FILE* f = fopen(path.c_str(), "rb");
  if (!f)
    return false;

  size_t bytes_read;
  char buff[1024*8];

  do {
    bytes_read = fread(buff, 1, sizeof(buff)-1, f);
    if (bytes_read > 0)
      resource_data.append(buff, bytes_read);
  } while (bytes_read > 0);

  fclose(f);
  return true;
}

CefRefPtr<CefStreamReader> GetBinaryResourceReader(const char* resource_name) {
  std::string path;
  if  (!GetResourceDir(path))
    return NULL;

  path.append("/");
  path.append(resource_name);

  return CefStreamReader::CreateForFile(path);
}
