// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#if defined(__linux__)
#include <wctype.h>
#endif

#include <algorithm>
#include <vector>
#include "include/wrapper/cef_zip_archive.h"
#include "include/cef_stream.h"
#include "include/cef_zip_reader.h"
#include "include/wrapper/cef_byte_read_handler.h"
#include "libcef_dll/cef_logging.h"

namespace {

class CefZipFile : public CefZipArchive::File {
 public:
  explicit CefZipFile(size_t size) : data_(size) {}
  ~CefZipFile() {}

  // Returns the read-only data contained in the file.
  virtual const unsigned char* GetData() { return &data_[0]; }

  // Returns the size of the data in the file.
  virtual size_t GetDataSize() { return data_.size(); }

  // Returns a CefStreamReader object for streaming the contents of the file.
  virtual CefRefPtr<CefStreamReader> GetStreamReader() {
    CefRefPtr<CefReadHandler> handler(
        new CefByteReadHandler(GetData(), GetDataSize(), this));
    return CefStreamReader::CreateForHandler(handler);
  }

  std::vector<unsigned char>* GetDataVector() { return &data_; }

 private:
  std::vector<unsigned char> data_;

  IMPLEMENT_REFCOUNTING(CefZipFile);
};

}  // namespace

// CefZipArchive implementation

CefZipArchive::CefZipArchive() {
}

CefZipArchive::~CefZipArchive() {
}

size_t CefZipArchive::Load(CefRefPtr<CefStreamReader> stream,
                           bool overwriteExisting) {
  AutoLock lock_scope(this);

  CefRefPtr<CefZipReader> reader(CefZipReader::Create(stream));
  if (!reader.get())
    return 0;

  if (!reader->MoveToFirstFile())
    return 0;

  std::wstring name;
  CefRefPtr<CefZipFile> contents;
  FileMap::iterator it;
  std::vector<unsigned char>* data;
  size_t count = 0, size, offset;

  do {
    size = static_cast<size_t>(reader->GetFileSize());
    if (size == 0) {
      // Skip directories and empty files.
      continue;
    }

    if (!reader->OpenFile(CefString()))
      break;

    name = reader->GetFileName();
    std::transform(name.begin(), name.end(), name.begin(), towlower);

    it = contents_.find(name);
    if (it != contents_.end()) {
      if (overwriteExisting)
        contents_.erase(it);
      else  // Skip files that already exist.
        continue;
    }

    contents = new CefZipFile(size);
    data = contents->GetDataVector();
    offset = 0;

    // Read the file contents.
    do {
     offset += reader->ReadFile(&(*data)[offset], size - offset);
    } while (offset < size && !reader->Eof());

    DCHECK(offset == size);

    reader->CloseFile();
    count++;

    // Add the file to the map.
    contents_.insert(std::make_pair(name, contents.get()));
  } while (reader->MoveToNextFile());

  return count;
}

void CefZipArchive::Clear() {
  AutoLock lock_scope(this);
  contents_.clear();
}

size_t CefZipArchive::GetFileCount() {
  AutoLock lock_scope(this);
  return contents_.size();
}

bool CefZipArchive::HasFile(const CefString& fileName) {
  std::wstring str = fileName;
  std::transform(str.begin(), str.end(), str.begin(), towlower);

  AutoLock lock_scope(this);
  FileMap::const_iterator it = contents_.find(CefString(str));
  return (it != contents_.end());
}

CefRefPtr<CefZipArchive::File> CefZipArchive::GetFile(
    const CefString& fileName) {
  std::wstring str = fileName;
  std::transform(str.begin(), str.end(), str.begin(), towlower);

  AutoLock lock_scope(this);
  FileMap::const_iterator it = contents_.find(CefString(str));
  if (it != contents_.end())
    return it->second;
  return NULL;
}

bool CefZipArchive::RemoveFile(const CefString& fileName) {
  std::wstring str = fileName;
  std::transform(str.begin(), str.end(), str.begin(), towlower);

  AutoLock lock_scope(this);
  FileMap::iterator it = contents_.find(CefString(str));
  if (it != contents_.end()) {
    contents_.erase(it);
    return true;
  }
  return false;
}

size_t CefZipArchive::GetFiles(FileMap& map) {
  AutoLock lock_scope(this);
  map = contents_;
  return contents_.size();
}
