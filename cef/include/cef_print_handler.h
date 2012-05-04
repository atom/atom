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

#ifndef CEF_INCLUDE_CEF_PRINT_HANDLER_H_
#define CEF_INCLUDE_CEF_PRINT_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"

///
// Implement this interface to handle events related to printing. The methods of
// this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefPrintHandler : public virtual CefBase {
 public:
  ///
  // Called to allow customization of standard print options before the print
  // dialog is displayed. |printOptions| allows specification of paper size,
  // orientation and margins. Note that the specified margins may be adjusted if
  // they are outside the range supported by the printer. All units are in
  // inches. Return false to display the default print options or true to
  // display the modified |printOptions|.
  ///
  /*--cef()--*/
  virtual bool GetPrintOptions(CefRefPtr<CefBrowser> browser,
                               CefPrintOptions& printOptions) { return false; }

  ///
  // Called to format print headers and footers. |printInfo| contains platform-
  // specific information about the printer context. |url| is the URL if the
  // currently printing page, |title| is the title of the currently printing
  // page, |currentPage| is the current page number and |maxPages| is the total
  // number of pages. Six default header locations are provided by the
  // implementation: top left, top center, top right, bottom left, bottom center
  // and bottom right. To use one of these default locations just assign a
  // string to the appropriate variable. To draw the header and footer yourself
  // return true. Otherwise, populate the approprate variables and return false.
  ///
  /*--cef()--*/
  virtual bool GetPrintHeaderFooter(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    const CefPrintInfo& printInfo,
                                    const CefString& url,
                                    const CefString& title,
                                    int currentPage,
                                    int maxPages,
                                    CefString& topLeft,
                                    CefString& topCenter,
                                    CefString& topRight,
                                    CefString& bottomLeft,
                                    CefString& bottomCenter,
                                    CefString& bottomRight) { return false; }
};

#endif  // CEF_INCLUDE_CEF_PRINT_HANDLER_H_
