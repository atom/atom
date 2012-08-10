// Copyright (c) 2012 Marshall A. Greenblatt. All rights reserved.
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
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//

#ifndef CEF_INCLUDE_CEF_ZIP_READER_H_
#define CEF_INCLUDE_CEF_ZIP_READER_H_

#include "include/cef_base.h"
#include "include/cef_stream.h"

///
// Class that supports the reading of zip archives via the zlib unzip API.
// The methods of this class should only be called on the thread that creates
// the object.
///
/*--cef(source=library)--*/
class CefZipReader : public virtual CefBase {
 public:
  ///
  // Create a new CefZipReader object. The returned object's methods can only
  // be called from the thread that created the object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefZipReader> Create(CefRefPtr<CefStreamReader> stream);

  ///
  // Moves the cursor to the first file in the archive. Returns true if the
  // cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToFirstFile() =0;

  ///
  // Moves the cursor to the next file in the archive. Returns true if the
  // cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToNextFile() =0;

  ///
  // Moves the cursor to the specified file in the archive. If |caseSensitive|
  // is true then the search will be case sensitive. Returns true if the cursor
  // position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToFile(const CefString& fileName, bool caseSensitive) =0;

  ///
  // Closes the archive. This should be called directly to ensure that cleanup
  // occurs on the correct thread.
  ///
  /*--cef()--*/
  virtual bool Close() =0;


  // The below methods act on the file at the current cursor position.

  ///
  // Returns the name of the file.
  ///
  /*--cef()--*/
  virtual CefString GetFileName() =0;

  ///
  // Returns the uncompressed size of the file.
  ///
  /*--cef()--*/
  virtual int64 GetFileSize() =0;

  ///
  // Returns the last modified timestamp for the file.
  ///
  /*--cef()--*/
  virtual time_t GetFileLastModified() =0;

  ///
  // Opens the file for reading of uncompressed data. A read password may
  // optionally be specified.
  ///
  /*--cef(optional_param=password)--*/
  virtual bool OpenFile(const CefString& password) =0;

  ///
  // Closes the file.
  ///
  /*--cef()--*/
  virtual bool CloseFile() =0;

  ///
  // Read uncompressed file contents into the specified buffer. Returns < 0 if
  // an error occurred, 0 if at the end of file, or the number of bytes read.
  ///
  /*--cef()--*/
  virtual int ReadFile(void* buffer, size_t bufferSize) =0;

  ///
  // Returns the current offset in the uncompressed file contents.
  ///
  /*--cef()--*/
  virtual int64 Tell() =0;

  ///
  // Returns true if at end of the file contents.
  ///
  /*--cef()--*/
  virtual bool Eof() =0;
};

#endif  // CEF_INCLUDE_CEF_ZIP_READER_H_
