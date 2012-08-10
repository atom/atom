// Copyright (c) 2008 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/browser/stream_impl.h"
#include <stdlib.h>
#include "base/logging.h"

// Static functions

CefRefPtr<CefStreamReader> CefStreamReader::CreateForFile(
    const CefString& fileName) {
  CefRefPtr<CefStreamReader> reader;
  std::string fileNameStr = fileName;
  FILE* file = fopen(fileNameStr.c_str(), "rb");
  if (file)
    reader = new CefFileReader(file, true);
  return reader;
}

CefRefPtr<CefStreamReader> CefStreamReader::CreateForData(void* data,
                                                          size_t size) {
  DCHECK(data != NULL);
  DCHECK(size > 0);  // NOLINT(readability/check)
  CefRefPtr<CefStreamReader> reader;
  if (data && size > 0)
    reader = new CefBytesReader(data, size, true);
  return reader;
}

CefRefPtr<CefStreamReader> CefStreamReader::CreateForHandler(
    CefRefPtr<CefReadHandler> handler) {
  DCHECK(handler.get());
  CefRefPtr<CefStreamReader> reader;
  if (handler.get())
    reader = new CefHandlerReader(handler);
  return reader;
}

CefRefPtr<CefStreamWriter> CefStreamWriter::CreateForFile(
    const CefString& fileName) {
  DCHECK(!fileName.empty());
  CefRefPtr<CefStreamWriter> writer;
  std::string fileNameStr = fileName;
  FILE* file = fopen(fileNameStr.c_str(), "wb");
  if (file)
    writer = new CefFileWriter(file, true);
  return writer;
}

CefRefPtr<CefStreamWriter> CefStreamWriter::CreateForHandler(
    CefRefPtr<CefWriteHandler> handler) {
  DCHECK(handler.get());
  CefRefPtr<CefStreamWriter> writer;
  if (handler.get())
    writer = new CefHandlerWriter(handler);
  return writer;
}


// CefFileReader

CefFileReader::CefFileReader(FILE* file, bool close)
  : close_(close), file_(file) {
}

CefFileReader::~CefFileReader() {
  AutoLock lock_scope(this);
  if (close_)
    fclose(file_);
}

size_t CefFileReader::Read(void* ptr, size_t size, size_t n) {
  AutoLock lock_scope(this);
  return fread(ptr, size, n, file_);
}

int CefFileReader::Seek(int64 offset, int whence) {
  AutoLock lock_scope(this);
#if defined(OS_WIN)
  return _fseeki64(file_, offset, whence);
#else
  return fseek(file_, offset, whence);
#endif
}

int64 CefFileReader::Tell() {
  AutoLock lock_scope(this);
#if defined(OS_WIN)
  return _ftelli64(file_);
#else
  return ftell(file_);
#endif
}

int CefFileReader::Eof() {
  AutoLock lock_scope(this);
  return feof(file_);
}


// CefFileWriter

CefFileWriter::CefFileWriter(FILE* file, bool close)
  : file_(file),
    close_(close) {
}

CefFileWriter::~CefFileWriter() {
  AutoLock lock_scope(this);
  if (close_)
    fclose(file_);
}

size_t CefFileWriter::Write(const void* ptr, size_t size, size_t n) {
  AutoLock lock_scope(this);
  return (size_t)fwrite(ptr, size, n, file_);
}

int CefFileWriter::Seek(int64 offset, int whence) {
  AutoLock lock_scope(this);
  return fseek(file_, offset, whence);
}

int64 CefFileWriter::Tell() {
  AutoLock lock_scope(this);
  return ftell(file_);
}

int CefFileWriter::Flush() {
  AutoLock lock_scope(this);
  return fflush(file_);
}


// CefBytesReader

CefBytesReader::CefBytesReader(void* data, int64 datasize, bool copy)
  : data_(NULL),
    datasize_(0),
    copy_(false),
    offset_(0) {
  SetData(data, datasize, copy);
}

CefBytesReader::~CefBytesReader() {
  SetData(NULL, 0, false);
}

size_t CefBytesReader::Read(void* ptr, size_t size, size_t n) {
  AutoLock lock_scope(this);
  size_t s = (datasize_ - offset_) / size;
  size_t ret = (n < s ? n : s);
  memcpy(ptr, (reinterpret_cast<char*>(data_)) + offset_, ret * size);
  offset_ += ret * size;
  return ret;
}

int CefBytesReader::Seek(int64 offset, int whence) {
  int rv = -1L;
  AutoLock lock_scope(this);
  switch (whence) {
  case SEEK_CUR:
    if (offset_ + offset > datasize_ || offset_ + offset < 0)
      break;
    offset_ += offset;
    rv = 0;
    break;
  case SEEK_END: {
    int64 offset_abs = abs(offset);
    if (offset_abs > datasize_)
      break;
    offset_ = datasize_ - offset_abs;
    rv = 0;
    break;
  }
  case SEEK_SET:
    if (offset > datasize_ || offset < 0)
      break;
    offset_ = offset;
    rv = 0;
    break;
  }

  return rv;
}

int64 CefBytesReader::Tell() {
  AutoLock lock_scope(this);
  return offset_;
}

int CefBytesReader::Eof() {
  AutoLock lock_scope(this);
  return (offset_ >= datasize_);
}

void CefBytesReader::SetData(void* data, int64 datasize, bool copy) {
  AutoLock lock_scope(this);
  if (copy_)
    free(data_);

  copy_ = copy;
  offset_ = 0;
  datasize_ = datasize;

  if (copy) {
    data_ = malloc(datasize);
    DCHECK(data_ != NULL);
    if (data_)
      memcpy(data_, data, datasize);
  } else {
    data_ = data;
  }
}


// CefBytesWriter

CefBytesWriter::CefBytesWriter(size_t grow)
  : grow_(grow),
    datasize_(grow),
    offset_(0) {
  DCHECK(grow > 0);  // NOLINT(readability/check)
  data_ = malloc(grow);
  DCHECK(data_ != NULL);
}

CefBytesWriter::~CefBytesWriter() {
  AutoLock lock_scope(this);
  if (data_)
    free(data_);
}

size_t CefBytesWriter::Write(const void* ptr, size_t size, size_t n) {
  AutoLock lock_scope(this);
  size_t rv;
  if (offset_ + static_cast<int64>(size * n) >= datasize_ &&
      Grow(size * n) == 0) {
    rv = 0;
  } else {
    memcpy(reinterpret_cast<char*>(data_) + offset_, ptr, size * n);
    offset_ += size * n;
    rv = n;
  }

  return rv;
}

int CefBytesWriter::Seek(int64 offset, int whence) {
  int rv = -1L;
  AutoLock lock_scope(this);
  switch (whence) {
  case SEEK_CUR:
    if (offset_ + offset > datasize_ || offset_ + offset < 0)
      break;
    offset_ += offset;
    rv = 0;
    break;
  case SEEK_END: {
    int64 offset_abs = abs(offset);
    if (offset_abs > datasize_)
      break;
    offset_ = datasize_ - offset_abs;
    rv = 0;
    break;
  }
  case SEEK_SET:
    if (offset > datasize_ || offset < 0)
      break;
    offset_ = offset;
    rv = 0;
    break;
  }

  return rv;
}

int64 CefBytesWriter::Tell() {
  AutoLock lock_scope(this);
  return offset_;
}

int CefBytesWriter::Flush() {
  return 0;
}

std::string CefBytesWriter::GetDataString() {
  AutoLock lock_scope(this);
  std::string str(reinterpret_cast<char*>(data_), offset_);
  return str;
}

size_t CefBytesWriter::Grow(size_t size) {
  AutoLock lock_scope(this);
  size_t rv;
  size_t s = (size > grow_ ? size : grow_);
  void* tmp = realloc(data_, datasize_ + s);
  DCHECK(tmp != NULL);
  if (tmp) {
    data_ = tmp;
    datasize_ += s;
    rv = datasize_;
  } else {
    rv = 0;
  }

  return rv;
}
