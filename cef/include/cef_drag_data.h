// Copyright (c) 2011 Marshall A. Greenblatt. All rights reserved.
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

#ifndef CEF_INCLUDE_CEF_DRAG_DATA_H_
#define CEF_INCLUDE_CEF_DRAG_DATA_H_
#pragma once

#include "include/cef_base.h"
#include <vector>

///
// Class used to represent drag data. The methods of this class may be called
// on any thread.
///
/*--cef(source=library)--*/
class CefDragData : public virtual CefBase {
 public:
  ///
  // Returns true if the drag data is a link.
  ///
  /*--cef()--*/
  virtual bool IsLink() =0;

  ///
  // Returns true if the drag data is a text or html fragment.
  ///
  /*--cef()--*/
  virtual bool IsFragment() =0;

  ///
  // Returns true if the drag data is a file.
  ///
  /*--cef()--*/
  virtual bool IsFile() =0;

  ///
  // Return the link URL that is being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetLinkURL() =0;

  ///
  // Return the title associated with the link being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetLinkTitle() =0;

  ///
  // Return the metadata, if any, associated with the link being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetLinkMetadata() =0;

  ///
  // Return the plain text fragment that is being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetFragmentText() =0;

  ///
  // Return the text/html fragment that is being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetFragmentHtml() =0;

  ///
  // Return the base URL that the fragment came from. This value is used for
  // resolving relative URLs and may be empty.
  ///
  /*--cef()--*/
  virtual CefString GetFragmentBaseURL() =0;

  ///
  // Return the extension of the file being dragged out of the browser window.
  ///
  /*--cef()--*/
  virtual CefString GetFileExtension() =0;

  ///
  // Return the name of the file being dragged out of the browser window.
  ///
  /*--cef()--*/
  virtual CefString GetFileName() =0;

  ///
  // Retrieve the list of file names that are being dragged into the browser
  // window.
  ///
  /*--cef()--*/
  virtual bool GetFileNames(std::vector<CefString>& names) =0;
};

#endif  // CEF_INCLUDE_CEF_DRAG_DATA_H_
