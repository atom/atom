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

#ifndef CEF_INCLUDE_CEF_CONTENT_FILTER_H_
#define CEF_INCLUDE_CEF_CONTENT_FILTER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_stream.h"

///
// Interface to implement for filtering response content. The methods of this
// class will always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefContentFilter : public virtual CefBase {
 public:
  ///
  // Set |substitute_data| to the replacement for the data in |data| if data
  // should be modified.
  ///
  /*--cef()--*/
  virtual void ProcessData(const void* data, int data_size,
                           CefRefPtr<CefStreamReader>& substitute_data) {}

  ///
  // Called when there is no more data to be processed. It is expected that
  // whatever data was retained in the last ProcessData() call, it should be
  // returned now by setting |remainder| if appropriate.
  ///
  /*--cef()--*/
  virtual void Drain(CefRefPtr<CefStreamReader>& remainder) {}
};

#endif  // CEF_INCLUDE_CEF_CONTENT_FILTER_H_
