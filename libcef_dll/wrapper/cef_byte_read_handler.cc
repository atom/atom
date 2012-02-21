// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_wrapper.h"
#include "libcef_dll/cef_logging.h"

CefByteReadHandler::CefByteReadHandler(const unsigned char* bytes, size_t size,
                                       CefRefPtr<CefBase> source)
  : bytes_(bytes), size_(size), offset_(0), source_(source)
{
}

size_t CefByteReadHandler::Read(void* ptr, size_t size, size_t n)
{
  AutoLock lock_scope(this);
  size_t s = (size_ - offset_) / size;
  size_t ret = std::min(n, s);
  memcpy(ptr, bytes_ + offset_, ret * size);
  offset_ += ret * size;
  return ret;
}

int CefByteReadHandler::Seek(long offset, int whence)
{
  int rv = -1L;
  AutoLock lock_scope(this);
  switch(whence) {
  case SEEK_CUR:
    if(offset_ + offset > size_)
      break;
    offset_ += offset;
    rv = 0;
    break;
  case SEEK_END:
    if(offset > static_cast<long>(size_))
      break;
    offset_ = size_ - offset;
    rv = 0;
    break;
  case SEEK_SET:
    if(offset > static_cast<long>(size_))
      break;
    offset_ = offset;
    rv = 0;
    break;
  }

  return rv;
}

long CefByteReadHandler::Tell()
{
  AutoLock lock_scope(this);
  return offset_;
}

int CefByteReadHandler::Eof()
{
  AutoLock lock_scope(this);
  return (offset_ >= size_);
}
