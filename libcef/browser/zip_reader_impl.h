// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_ZIP_READER_IMPL_H_
#define CEF_LIBCEF_BROWSER_ZIP_READER_IMPL_H_
#pragma once

#include <sstream>

#include "include/cef_zip_reader.h"
#include "base/threading/platform_thread.h"
#include "third_party/zlib/contrib/minizip/unzip.h"

// Implementation of CefZipReader
class CefZipReaderImpl : public CefZipReader {
 public:
  CefZipReaderImpl();
  ~CefZipReaderImpl();

  // Initialize the reader context.
  bool Initialize(CefRefPtr<CefStreamReader> stream);

  virtual bool MoveToFirstFile();
  virtual bool MoveToNextFile();
  virtual bool MoveToFile(const CefString& fileName, bool caseSensitive);
  virtual bool Close();
  virtual CefString GetFileName();
  virtual int64 GetFileSize();
  virtual time_t GetFileLastModified();
  virtual bool OpenFile(const CefString& password);
  virtual bool CloseFile();
  virtual int ReadFile(void* buffer, size_t bufferSize);
  virtual int64 Tell();
  virtual bool Eof();

  bool GetFileInfo();

  // Verify that the reader exists and is being accessed from the correct
  // thread.
  bool VerifyContext();

 protected:
  base::PlatformThreadId supported_thread_id_;
  unzFile reader_;
  bool has_fileopen_;
  bool has_fileinfo_;
  CefString filename_;
  int64 filesize_;
  time_t filemodified_;

  IMPLEMENT_REFCOUNTING(CefZipReaderImpl);
};

#endif  // CEF_LIBCEF_BROWSER_ZIP_READER_IMPL_H_
