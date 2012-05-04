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

#ifndef CEF_INCLUDE_CEF_FOCUS_HANDLER_H_
#define CEF_INCLUDE_CEF_FOCUS_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_dom.h"
#include "include/cef_frame.h"

///
// Implement this interface to handle events related to focus. The methods of
// this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefFocusHandler : public virtual CefBase {
 public:
  typedef cef_handler_focus_source_t FocusSource;

  ///
  // Called when the browser component is about to loose focus. For instance, if
  // focus was on the last HTML element and the user pressed the TAB key. |next|
  // will be true if the browser is giving focus to the next component and false
  // if the browser is giving focus to the previous component.
  ///
  /*--cef()--*/
  virtual void OnTakeFocus(CefRefPtr<CefBrowser> browser,
                           bool next) {}

  ///
  // Called when the browser component is requesting focus. |source| indicates
  // where the focus request is originating from. Return false to allow the
  // focus to be set or true to cancel setting the focus.
  ///
  /*--cef()--*/
  virtual bool OnSetFocus(CefRefPtr<CefBrowser> browser,
                          FocusSource source) { return false; }

  ///
  // Called when a new node in the the browser gets focus. The |node| value may
  // be empty if no specific node has gained focus. The node object passed to
  // this method represents a snapshot of the DOM at the time this method is
  // executed. DOM objects are only valid for the scope of this method. Do not
  // keep references to or attempt to access any DOM objects outside the scope
  // of this method.
  ///
  /*--cef(optional_param=frame,optional_param=node)--*/
  virtual void OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefDOMNode> node) {}
};

#endif  // CEF_INCLUDE_CEF_FOCUS_HANDLER_H_
