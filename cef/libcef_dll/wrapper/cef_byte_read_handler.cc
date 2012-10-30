// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/wrapper/cef_byte_read_handler.h"
#include <stdlib.h>
#include "libcef_dll/cef_logging.h"

CefByteReadHandler::CefByteReadHandler(const unsigned char* bytes, size_t size,
                                       CefRefPtr<CefBase> source)
  : bytes_(bytes), size_(size), offset_(0), source_(source) {
}

size_t CefByteReadHandler::Read(void* ptr, size_t size, size_t n) {
  AutoLock lock_scope(this);
  size_t s = static_cast<size_t>(size_ - offset_) / size;
  size_t ret = std::min(n, s);
  memcpy(ptr, bytes_ + offset_, ret * size);
  offset_ += ret * size;
  return ret;
}

int CefByteReadHandler::Seek(int64 offset, int whence) {
  int rv = -1L;
  AutoLock lock_scope(this);
  switch (whence) {
  case SEEK_CUR:
    if (offset_ + offset > size_ || offset_ + offset < 0)
      break;
    offset_ += offset;
    rv = 0;
    break;
  case SEEK_END: {
#if defined(OS_WIN)
    int64 offset_abs = _abs64(offset);
#else
    int64 offset_abs = abs(offset);
#endif
    if (offset_abs > size_)
      break;
    offset_ = size_ - offset_abs;
    rv = 0;
    break;
  }
  case SEEK_SET:
    if (offset > size_ || offset < 0)
      break;
    offset_ = offset;
    rv = 0;
    break;
  }

  return rv;
}

int64 CefByteReadHandler::Tell() {
  AutoLock lock_scope(this);
  return offset_;
}

int CefByteReadHandler::Eof() {
  AutoLock lock_scope(this);
  return (offset_ >= size_);
}
