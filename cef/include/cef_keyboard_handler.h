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

#ifndef CEF_INCLUDE_CEF_KEYBOARD_HANDLER_H_
#define CEF_INCLUDE_CEF_KEYBOARD_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"

///
// Implement this interface to handle events related to keyboard input. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefKeyboardHandler : public virtual CefBase {
 public:
  typedef cef_handler_keyevent_type_t KeyEventType;

  ///
  // Called when the browser component receives a keyboard event. This method
  // is called both before the event is passed to the renderer and after
  // JavaScript in the page has had a chance to handle the event. |type| is the
  // type of keyboard event, |code| is the windows scan-code for the event,
  // |modifiers| is a set of bit- flags describing any pressed modifier keys and
  // |isSystemKey| is true if Windows considers this a 'system key' message (see
  // http://msdn.microsoft.com/en-us/library/ms646286(VS.85).aspx). If
  // |isAfterJavaScript| is true then JavaScript in the page has had a chance
  // to handle the event and has chosen not to. Only RAWKEYDOWN, KEYDOWN and
  // CHAR events will be sent with |isAfterJavaScript| set to true. Return
  // true if the keyboard event was handled or false to allow continued handling
  // of the event by the renderer.
  ///
  /*--cef()--*/
  virtual bool OnKeyEvent(CefRefPtr<CefBrowser> browser,
                          KeyEventType type,
                          int code,
                          int modifiers,
                          bool isSystemKey,
                          bool isAfterJavaScript) { return false; }
};

#endif  // CEF_INCLUDE_CEF_KEYBOARD_HANDLER_H_
