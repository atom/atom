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

#ifndef CEF_INCLUDE_CEF_FIND_HANDLER_H_
#define CEF_INCLUDE_CEF_FIND_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"

///
// Implement this interface to handle events related to find results. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefFindHandler : public virtual CefBase {
 public:
  ///
  // Called to report find results returned by CefBrowser::Find(). |identifer|
  // is the identifier passed to CefBrowser::Find(), |count| is the number of
  // matches currently identified, |selectionRect| is the location of where the
  // match was found (in window coordinates), |activeMatchOrdinal| is the
  // current position in the search results, and |finalUpdate| is true if this
  // is the last find notification.
  ///
  /*--cef()--*/
  virtual void OnFindResult(CefRefPtr<CefBrowser> browser,
                            int identifier,
                            int count,
                            const CefRect& selectionRect,
                            int activeMatchOrdinal,
                            bool finalUpdate) {}
};

#endif  // CEF_INCLUDE_CEF_FIND_HANDLER_H_
