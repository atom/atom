// Copyright (c) 2011 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include "cefclient/resource_util.h"
#include "include/cef_stream.h"
#include "cefclient/util.h"

namespace {

bool AmIBundled() {
  // Implementation adapted from Chromium's base/mac/foundation_util.mm
  ProcessSerialNumber psn = {0, kCurrentProcess};
  
  FSRef fsref;
  OSStatus pbErr;
  if ((pbErr = GetProcessBundleLocation(&psn, &fsref)) != noErr) {
    ASSERT(false);
    return false;
  }
  
  FSCatalogInfo info;
  OSErr fsErr;
  if ((fsErr = FSGetCatalogInfo(&fsref, kFSCatInfoNodeFlags, &info,
                                NULL, NULL, NULL)) != noErr) {
    ASSERT(false);
    return false;
  }
  
  return (info.nodeFlags & kFSNodeIsDirectoryMask);
}

bool GetResourceDir(std::string& dir) {
	// Implementation adapted from Chromium's base/base_path_mac.mm
	if (AmIBundled()) {
    // Retrieve the executable directory.
    uint32_t pathSize = 0;
    _NSGetExecutablePath(NULL, &pathSize);
    if (pathSize > 0) {      
      dir.resize(pathSize);
      _NSGetExecutablePath(const_cast<char*>(dir.c_str()), &pathSize);
    }

    // Trim executable name up to the last separator
    std::string::size_type last_separator = dir.find_last_of("/");
    dir.resize(last_separator);
    dir.append("/../Resources");
    return true;
  } else {
    // TODO: Provide unbundled path
    ASSERT(false);
    return false;
  }
}

bool ReadFileToString(const char* path, std::string& data) {
  // Implementation adapted from base/file_util.cc
  FILE* file = fopen(path, "rb");
  if (!file)
    return false;

  char buf[1 << 16];
  size_t len;
  while ((len = fread(buf, 1, sizeof(buf), file)) > 0)
    data.append(buf, len);
  fclose(file);
  
  return true;
}
  
} // namespace

bool LoadBinaryResource(const char* resource_name, std::string& resource_data) {
  std::string path;
  if (!GetResourceDir(path))
    return false;

  path.append("/");
  path.append(resource_name);
    
  return ReadFileToString(path.c_str(), resource_data);
}

CefRefPtr<CefStreamReader> GetBinaryResourceReader(const char* resource_name) {
  std::string path;
  if (!GetResourceDir(path))
    return NULL;
  
  path.append("/");
  path.append(resource_name);
  
  return CefStreamReader::CreateForFile(path);
}
