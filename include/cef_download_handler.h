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

#ifndef CEF_INCLUDE_CEF_DOWNLOAD_HANDLER_H_
#define CEF_INCLUDE_CEF_DOWNLOAD_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_download_item.h"


///
// Callback interface used to asynchronously continue a download.
///
/*--cef(source=library)--*/
class CefBeforeDownloadCallback : public virtual CefBase {
 public:
  ///
  // Call to continue the download. Set |download_path| to the full file path
  // for the download including the file name or leave blank to use the
  // suggested name and the default temp directory. Set |show_dialog| to true
  // if you do wish to show the default "Save As" dialog.
  ///
  /*--cef(capi_name=cont,optional_param=download_path)--*/
  virtual void Continue(const CefString& download_path, bool show_dialog) =0;
};


///
// Callback interface used to asynchronously cancel a download.
///
/*--cef(source=library)--*/
class CefDownloadItemCallback : public virtual CefBase {
 public:
  ///
  // Call to cancel the download.
  ///
  /*--cef()--*/
  virtual void Cancel() =0;
};


///
// Class used to handle file downloads. The methods of this class will called
// on the browser process UI thread.
///
/*--cef(source=client)--*/
class CefDownloadHandler : public virtual CefBase {
 public:
  ///
  // Called before a download begins. |suggested_name| is the suggested name for
  // the download file. By default the download will be canceled. Execute
  // |callback| either asynchronously or in this method to continue the download
  // if desired. Do not keep a reference to |download_item| outside of this
  // method.
  ///
  /*--cef()--*/
  virtual void OnBeforeDownload(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefDownloadItem> download_item,
      const CefString& suggested_name,
      CefRefPtr<CefBeforeDownloadCallback> callback) =0;

  ///
  // Called when a download's status or progress information has been updated.
  // Execute |callback| either asynchronously or in this method to cancel the
  // download if desired. Do not keep a reference to |download_item| outside of
  // this method.
  ///
  /*--cef()--*/
  virtual void OnDownloadUpdated(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefDownloadItem> download_item,
      CefRefPtr<CefDownloadItemCallback> callback) {}
};

#endif  // CEF_INCLUDE_CEF_DOWNLOAD_HANDLER_H_
