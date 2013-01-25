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

#ifndef CEF_INCLUDE_CEF_DOWNLOAD_ITEM_H_
#define CEF_INCLUDE_CEF_DOWNLOAD_ITEM_H_
#pragma once

#include "include/cef_base.h"

///
// Class used to represent a download item.
///
/*--cef(source=library)--*/
class CefDownloadItem : public virtual CefBase {
 public:
  ///
  // Returns true if this object is valid. Do not call any other methods if this
  // function returns false.
  ///
  /*--cef()--*/
  virtual bool IsValid() =0;

  ///
  // Returns true if the download is in progress.
  ///
  /*--cef()--*/
  virtual bool IsInProgress() =0;

  ///
  // Returns true if the download is complete.
  ///
  /*--cef()--*/
  virtual bool IsComplete() =0;

  ///
  // Returns true if the download has been canceled or interrupted.
  ///
  /*--cef()--*/
  virtual bool IsCanceled() =0;

  ///
  // Returns a simple speed estimate in bytes/s.
  ///
  /*--cef()--*/
  virtual int64 GetCurrentSpeed() =0;

  ///
  // Returns the rough percent complete or -1 if the receive total size is
  // unknown.
  ///
  /*--cef()--*/
  virtual int GetPercentComplete() =0;

  ///
  // Returns the total number of bytes.
  ///
  /*--cef()--*/
  virtual int64 GetTotalBytes() =0;

  ///
  // Returns the number of received bytes.
  ///
  /*--cef()--*/
  virtual int64 GetReceivedBytes() =0;

  ///
  // Returns the time that the download started.
  ///
  /*--cef()--*/
  virtual CefTime GetStartTime() =0;

  ///
  // Returns the time that the download ended.
  ///
  /*--cef()--*/
  virtual CefTime GetEndTime() =0;

  ///
  // Returns the full path to the downloaded or downloading file.
  ///
  /*--cef()--*/
  virtual CefString GetFullPath() =0;

  ///
  // Returns the unique identifier for this download.
  ///
  /*--cef()--*/
  virtual int32 GetId() =0;

  ///
  // Returns the URL.
  ///
  /*--cef()--*/
  virtual CefString GetURL() =0;

  ///
  // Returns the suggested file name.
  ///
  /*--cef()--*/
  virtual CefString GetSuggestedFileName() =0;

  ///
  // Returns the content disposition.
  ///
  /*--cef()--*/
  virtual CefString GetContentDisposition() =0;

  ///
  // Returns the mime type.
  ///
  /*--cef()--*/
  virtual CefString GetMimeType() =0;
};

#endif  // CEF_INCLUDE_CEF_DOWNLOAD_ITEM_H_
