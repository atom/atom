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

#ifndef CEF_INCLUDE_CEF_STREAM_H_
#define CEF_INCLUDE_CEF_STREAM_H_

#include "include/cef_base.h"

///
// Interface the client can implement to provide a custom stream reader. The
// methods of this class may be called on any thread.
///
/*--cef(source=client)--*/
class CefReadHandler : public virtual CefBase {
 public:
  ///
  // Read raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Read(void* ptr, size_t size, size_t n) =0;

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET. Return zero on success and non-zero on
  // failure.
  ///
  /*--cef()--*/
  virtual int Seek(int64 offset, int whence) =0;

  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual int64 Tell() =0;

  ///
  // Return non-zero if at end of file.
  ///
  /*--cef()--*/
  virtual int Eof() =0;
};


///
// Class used to read data from a stream. The methods of this class may be
// called on any thread.
///
/*--cef(source=library)--*/
class CefStreamReader : public virtual CefBase {
 public:
  ///
  // Create a new CefStreamReader object from a file.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamReader> CreateForFile(const CefString& fileName);
  ///
  // Create a new CefStreamReader object from data.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamReader> CreateForData(void* data, size_t size);
  ///
  // Create a new CefStreamReader object from a custom handler.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamReader> CreateForHandler(
      CefRefPtr<CefReadHandler> handler);

  ///
  // Read raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Read(void* ptr, size_t size, size_t n) =0;

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET. Returns zero on success and non-zero on
  // failure.
  ///
  /*--cef()--*/
  virtual int Seek(int64 offset, int whence) =0;

  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual int64 Tell() =0;

  ///
  // Return non-zero if at end of file.
  ///
  /*--cef()--*/
  virtual int Eof() =0;
};


///
// Interface the client can implement to provide a custom stream writer. The
// methods of this class may be called on any thread.
///
/*--cef(source=client)--*/
class CefWriteHandler : public virtual CefBase {
 public:
  ///
  // Write raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Write(const void* ptr, size_t size, size_t n) =0;

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET. Return zero on success and non-zero on
  // failure.
  ///
  /*--cef()--*/
  virtual int Seek(int64 offset, int whence) =0;

  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual int64 Tell() =0;

  ///
  // Flush the stream.
  ///
  /*--cef()--*/
  virtual int Flush() =0;
};


///
// Class used to write data to a stream. The methods of this class may be called
// on any thread.
///
/*--cef(source=library)--*/
class CefStreamWriter : public virtual CefBase {
 public:
  ///
  // Create a new CefStreamWriter object for a file.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamWriter> CreateForFile(const CefString& fileName);
  ///
  // Create a new CefStreamWriter object for a custom handler.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamWriter> CreateForHandler(
      CefRefPtr<CefWriteHandler> handler);

  ///
  // Write raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Write(const void* ptr, size_t size, size_t n) =0;

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET. Returns zero on success and non-zero on
  // failure.
  ///
  /*--cef()--*/
  virtual int Seek(int64 offset, int whence) =0;

  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual int64 Tell() =0;

  ///
  // Flush the stream.
  ///
  /*--cef()--*/
  virtual int Flush() =0;
};

#endif  // CEF_INCLUDE_CEF_STREAM_H_
