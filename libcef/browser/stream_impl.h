// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_STREAM_IMPL_H_
#define CEF_LIBCEF_BROWSER_STREAM_IMPL_H_
#pragma once

#include <stdio.h>
#include <string>
#include "include/cef_stream.h"

// Implementation of CefStreamReader for files.
class CefFileReader : public CefStreamReader {
 public:
  CefFileReader(FILE* file, bool close);
  virtual ~CefFileReader();

  virtual size_t Read(void* ptr, size_t size, size_t n) OVERRIDE;
  virtual int Seek(int64 offset, int whence) OVERRIDE;
  virtual int64 Tell() OVERRIDE;
  virtual int Eof() OVERRIDE;

 protected:
  bool close_;
  FILE* file_;

  IMPLEMENT_REFCOUNTING(CefFileReader);
  IMPLEMENT_LOCKING(CefFileReader);
};

// Implementation of CefStreamWriter for files.
class CefFileWriter : public CefStreamWriter {
 public:
  CefFileWriter(FILE* file, bool close);
  virtual ~CefFileWriter();

  virtual size_t Write(const void* ptr, size_t size, size_t n) OVERRIDE;
  virtual int Seek(int64 offset, int whence) OVERRIDE;
  virtual int64 Tell() OVERRIDE;
  virtual int Flush() OVERRIDE;

 protected:
  FILE* file_;
  bool close_;

  IMPLEMENT_REFCOUNTING(CefFileWriter);
  IMPLEMENT_LOCKING(CefFileWriter);
};

// Implementation of CefStreamReader for byte buffers.
class CefBytesReader : public CefStreamReader {
 public:
  CefBytesReader(void* data, int64 datasize, bool copy);
  virtual ~CefBytesReader();

  virtual size_t Read(void* ptr, size_t size, size_t n) OVERRIDE;
  virtual int Seek(int64 offset, int whence) OVERRIDE;
  virtual int64 Tell() OVERRIDE;
  virtual int Eof() OVERRIDE;

  void SetData(void* data, int64 datasize, bool copy);

  void* GetData() { return data_; }
  size_t GetDataSize() { return offset_; }

 protected:
  void* data_;
  int64 datasize_;
  bool copy_;
  int64 offset_;

  IMPLEMENT_REFCOUNTING(CefBytesReader);
  IMPLEMENT_LOCKING(CefBytesReader);
};

// Implementation of CefStreamWriter for byte buffers.
class CefBytesWriter : public CefStreamWriter {
 public:
  explicit CefBytesWriter(size_t grow);
  virtual ~CefBytesWriter();

  virtual size_t Write(const void* ptr, size_t size, size_t n) OVERRIDE;
  virtual int Seek(int64 offset, int whence) OVERRIDE;
  virtual int64 Tell() OVERRIDE;
  virtual int Flush() OVERRIDE;

  void* GetData() { return data_; }
  int64 GetDataSize() { return offset_; }
  std::string GetDataString();

 protected:
  size_t Grow(size_t size);

  size_t grow_;
  void* data_;
  int64 datasize_;
  int64 offset_;

  IMPLEMENT_REFCOUNTING(CefBytesWriter);
  IMPLEMENT_LOCKING(CefBytesWriter);
};

// Implementation of CefStreamReader for handlers.
class CefHandlerReader : public CefStreamReader {
 public:
  explicit CefHandlerReader(CefRefPtr<CefReadHandler> handler)
      : handler_(handler) {}

  virtual size_t Read(void* ptr, size_t size, size_t n) OVERRIDE {
    return handler_->Read(ptr, size, n);
  }
  virtual int Seek(int64 offset, int whence) OVERRIDE {
    return handler_->Seek(offset, whence);
  }
  virtual int64 Tell() OVERRIDE {
    return handler_->Tell();
  }
  virtual int Eof() OVERRIDE {
    return handler_->Eof();
  }

 protected:
  CefRefPtr<CefReadHandler> handler_;

  IMPLEMENT_REFCOUNTING(CefHandlerReader);
};

// Implementation of CefStreamWriter for handlers.
class CefHandlerWriter : public CefStreamWriter {
 public:
  explicit CefHandlerWriter(CefRefPtr<CefWriteHandler> handler)
      : handler_(handler) {}

  virtual size_t Write(const void* ptr, size_t size, size_t n) OVERRIDE {
    return handler_->Write(ptr, size, n);
  }
  virtual int Seek(int64 offset, int whence) OVERRIDE {
    return handler_->Seek(offset, whence);
  }
  virtual int64 Tell() OVERRIDE {
    return handler_->Tell();
  }
  virtual int Flush() OVERRIDE {
    return handler_->Flush();
  }

 protected:
  CefRefPtr<CefWriteHandler> handler_;

  IMPLEMENT_REFCOUNTING(CefHandlerWriter);
};

#endif  // CEF_LIBCEF_BROWSER_STREAM_IMPL_H_
