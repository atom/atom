// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/browser/zip_reader_impl.h"
#include <time.h>
#include "include/cef_stream.h"
#include "base/logging.h"

// Static functions

// static
CefRefPtr<CefZipReader> CefZipReader::Create(
    CefRefPtr<CefStreamReader> stream) {
  CefRefPtr<CefZipReaderImpl> impl(new CefZipReaderImpl());
  if (!impl->Initialize(stream))
    return NULL;
  return impl.get();
}


// CefZipReaderImpl

namespace {

voidpf ZCALLBACK zlib_open_callback OF((voidpf opaque, const void* filename,
                                       int mode)) {
  // The stream is already implicitly open so just return the pointer.
  return opaque;
}

uLong ZCALLBACK zlib_read_callback OF((voidpf opaque, voidpf stream, void* buf,
                                      uLong size)) {
  CefRefPtr<CefStreamReader> reader(static_cast<CefStreamReader*>(opaque));
  return reader->Read(buf, 1, size);
}

ZPOS64_T ZCALLBACK zlib_tell_callback OF((voidpf opaque, voidpf stream)) {
  CefRefPtr<CefStreamReader> reader(static_cast<CefStreamReader*>(opaque));
  return reader->Tell();
}

long ZCALLBACK zlib_seek_callback OF((voidpf opaque,  // NOLINT(runtime/int)
                                     voidpf stream, ZPOS64_T offset,
                                     int origin)) {
  CefRefPtr<CefStreamReader> reader(static_cast<CefStreamReader*>(opaque));
  int whence;
  switch (origin) {
    case ZLIB_FILEFUNC_SEEK_CUR:
      whence = SEEK_CUR;
      break;
    case ZLIB_FILEFUNC_SEEK_END:
      whence = SEEK_END;
      break;
    case ZLIB_FILEFUNC_SEEK_SET:
      whence = SEEK_SET;
      break;
    default:
      NOTREACHED();
      return -1;
  }
  return reader->Seek(offset, whence);
}

int ZCALLBACK zlib_close_callback OF((voidpf opaque, voidpf stream)) {
  CefRefPtr<CefStreamReader> reader(static_cast<CefStreamReader*>(opaque));
  // Release the reference added by CefZipReaderImpl::Initialize().
  reader->Release();
  return 0;
}

int ZCALLBACK zlib_error_callback OF((voidpf opaque, voidpf stream)) {
  return 0;
}

}  // namespace

CefZipReaderImpl::CefZipReaderImpl()
  : supported_thread_id_(base::PlatformThread::CurrentId()), reader_(NULL),
    has_fileopen_(false),
    has_fileinfo_(false),
    filesize_(0),
    filemodified_(0) {
}

CefZipReaderImpl::~CefZipReaderImpl() {
  if (reader_ != NULL) {
    if (!VerifyContext()) {
      // Close() is supposed to be called directly. We'll try to free the reader
      // now on the wrong thread but there's no guarantee this call won't crash.
      if (has_fileopen_)
        unzCloseCurrentFile(reader_);
      unzClose(reader_);
    } else {
      Close();
    }
  }
}

bool CefZipReaderImpl::Initialize(CefRefPtr<CefStreamReader> stream) {
  zlib_filefunc64_def filefunc_def;
  filefunc_def.zopen64_file = zlib_open_callback;
  filefunc_def.zread_file = zlib_read_callback;
  filefunc_def.zwrite_file = NULL;
  filefunc_def.ztell64_file = zlib_tell_callback;
  filefunc_def.zseek64_file = zlib_seek_callback;
  filefunc_def.zclose_file = zlib_close_callback;
  filefunc_def.zerror_file = zlib_error_callback;
  filefunc_def.opaque = stream.get();

  // Add a reference that will be released by zlib_close_callback().
  stream->AddRef();

  reader_ = unzOpen2_64("", &filefunc_def);
  return (reader_ != NULL);
}

bool CefZipReaderImpl::MoveToFirstFile() {
  if (!VerifyContext())
    return false;

  if (has_fileopen_)
    CloseFile();

  has_fileinfo_ = false;

  return (unzGoToFirstFile(reader_) == UNZ_OK);
}

bool CefZipReaderImpl::MoveToNextFile() {
  if (!VerifyContext())
    return false;

  if (has_fileopen_)
    CloseFile();

  has_fileinfo_ = false;

  return (unzGoToNextFile(reader_) == UNZ_OK);
}

bool CefZipReaderImpl::MoveToFile(const CefString& fileName,
                                  bool caseSensitive) {
  if (!VerifyContext())
    return false;

  if (has_fileopen_)
    CloseFile();

  has_fileinfo_ = false;

  std::string fileNameStr = fileName;
  return (unzLocateFile(reader_, fileNameStr.c_str(),
                        (caseSensitive ? 1 : 2)) == UNZ_OK);
}

bool CefZipReaderImpl::Close() {
  if (!VerifyContext())
    return false;

  if (has_fileopen_)
    CloseFile();

  int result = unzClose(reader_);
  reader_ = NULL;
  return (result == UNZ_OK);
}

CefString CefZipReaderImpl::GetFileName() {
  if (!VerifyContext() || !GetFileInfo())
    return CefString();

  return filename_;
}

int64 CefZipReaderImpl::GetFileSize() {
  if (!VerifyContext() || !GetFileInfo())
    return -1;

  return filesize_;
}

time_t CefZipReaderImpl::GetFileLastModified() {
  if (!VerifyContext() || !GetFileInfo())
    return 0;

  return filemodified_;
}

bool CefZipReaderImpl::OpenFile(const CefString& password) {
  if (!VerifyContext())
    return false;

  if (has_fileopen_)
    CloseFile();

  bool ret;

  if (password.empty()) {
    ret = (unzOpenCurrentFile(reader_) == UNZ_OK);
  } else {
    std::string passwordStr = password;
    ret = (unzOpenCurrentFilePassword(reader_, passwordStr.c_str()) == UNZ_OK);
  }

  if (ret)
    has_fileopen_ = true;
  return ret;
}

bool CefZipReaderImpl::CloseFile() {
  if (!VerifyContext() || !has_fileopen_)
    return false;

  has_fileopen_ = false;
  has_fileinfo_ = false;

  return (unzCloseCurrentFile(reader_) == UNZ_OK);
}

int CefZipReaderImpl::ReadFile(void* buffer, size_t bufferSize) {
  if (!VerifyContext() || !has_fileopen_)
    return -1;

  return unzReadCurrentFile(reader_, buffer, bufferSize);
}

int64 CefZipReaderImpl::Tell() {
  if (!VerifyContext() || !has_fileopen_)
    return -1;

  return unztell64(reader_);
}

bool CefZipReaderImpl::Eof() {
  if (!VerifyContext() || !has_fileopen_)
    return true;

  return (unzeof(reader_) == 1 ? true : false);
}

bool CefZipReaderImpl::GetFileInfo() {
  if (has_fileinfo_)
    return true;

  char file_name[512] = {0};
  unz_file_info file_info;
  memset(&file_info, 0, sizeof(file_info));

  if (unzGetCurrentFileInfo(reader_, &file_info, file_name, sizeof(file_name),
                            NULL, 0, NULL, 0) != UNZ_OK) {
    return false;
  }

  has_fileinfo_ = true;
  filename_ = std::string(file_name);
  filesize_ = file_info.uncompressed_size;

  struct tm time;
  memset(&time, 0, sizeof(time));
  time.tm_sec = file_info.tmu_date.tm_sec;
  time.tm_min = file_info.tmu_date.tm_min;
  time.tm_hour = file_info.tmu_date.tm_hour;
  time.tm_mday = file_info.tmu_date.tm_mday;
  time.tm_mon = file_info.tmu_date.tm_mon;
  time.tm_year = file_info.tmu_date.tm_year;
  filemodified_ = mktime(&time);

  return true;
}

bool CefZipReaderImpl::VerifyContext() {
  if (base::PlatformThread::CurrentId() != supported_thread_id_) {
    // This object should only be accessed from the thread that created it.
    NOTREACHED();
    return false;
  }

  return (reader_ != NULL);
}
