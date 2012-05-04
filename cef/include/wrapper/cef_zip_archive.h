// Copyright (c) 2011 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ---------------------------------------------------------------------------
//
// The contents of this file are only available to applications that link
// against the libcef_dll_wrapper target.
//

#ifndef CEF_INCLUDE_WRAPPER_CEF_ZIP_ARCHIVE_H_
#define CEF_INCLUDE_WRAPPER_CEF_ZIP_ARCHIVE_H_
#pragma once

#include "include/cef_base.h"
#include <map>

class CefStreamReader;

///
// Thread-safe class for accessing zip archive file contents. This class should
// not be used with large archive files because all data will be resident in
// memory at the same time. This implementation supports a restricted set of zip
// archive features:
// (1) Password-protected files are not supported.
// (2) All file names are stored and compared in lower case.
// (3) File ordering from the original zip archive is not maintained. This
//     means that files from the same folder may not be located together in the
//     file content map.
///
class CefZipArchive : public CefBase {
 public:
  ///
  // Class representing a file in the archive. Accessing the file data from
  // multiple threads is safe provided a reference to the File object is kept.
  ///
  class File : public CefBase {
   public:
    ///
    // Returns the read-only data contained in the file.
    ///
    virtual const unsigned char* GetData() =0;

    ///
    // Returns the size of the data in the file.
    ///
    virtual size_t GetDataSize() =0;

    ///
    // Returns a CefStreamReader object for streaming the contents of the file.
    ///
    virtual CefRefPtr<CefStreamReader> GetStreamReader() =0;
  };
  typedef std::map<CefString, CefRefPtr<File> > FileMap;

  ///
  // Create a new object.
  ///
  CefZipArchive();
  virtual ~CefZipArchive();

  ///
  // Load the contents of the specified zip archive stream into this object.
  // If |overwriteExisting| is true then any files in this object that also
  // exist in the specified archive will be replaced with the new files.
  // Returns the number of files successfully loaded.
  ///
  size_t Load(CefRefPtr<CefStreamReader> stream, bool overwriteExisting);

  ///
  // Clears the contents of this object.
  ///
  void Clear();

  ///
  // Returns the number of files in the archive.
  ///
  size_t GetFileCount();

  ///
  // Returns true if the specified file exists and has contents.
  ///
  bool HasFile(const CefString& fileName);

  ///
  // Returns the specified file.
  ///
  CefRefPtr<File> GetFile(const CefString& fileName);

  ///
  // Removes the specified file.
  ///
  bool RemoveFile(const CefString& fileName);

  ///
  // Returns the map of all files.
  ///
  size_t GetFiles(FileMap& map);

 private:
  FileMap contents_;

  IMPLEMENT_REFCOUNTING(CefZipArchive);
  IMPLEMENT_LOCKING(CefZipArchive);
};

#endif  // CEF_INCLUDE_WRAPPER_CEF_ZIP_ARCHIVE_H_
