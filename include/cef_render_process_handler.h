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

#ifndef CEF_INCLUDE_CEF_RENDER_PROCESS_HANDLER_H_
#define CEF_INCLUDE_CEF_RENDER_PROCESS_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_dom.h"
#include "include/cef_frame.h"
#include "include/cef_process_message.h"
#include "include/cef_v8.h"

///
// Class used to implement render process callbacks. The methods of this class
// will always be called on the render process main thread.
///
/*--cef(source=client)--*/
class CefRenderProcessHandler : public virtual CefBase {
 public:
  ///
  // Called after the render process main thread has been created.
  ///
  /*--cef()--*/
  virtual void OnRenderThreadCreated() {}

  ///
  // Called after WebKit has been initialized.
  ///
  /*--cef()--*/
  virtual void OnWebKitInitialized() {}

  ///
  // Called after a browser has been created.
  ///
  /*--cef()--*/
  virtual void OnBrowserCreated(CefRefPtr<CefBrowser> browser) {}

  ///
  // Called before a browser is destroyed.
  ///
  /*--cef()--*/
  virtual void OnBrowserDestroyed(CefRefPtr<CefBrowser> browser) {}

  ///
  // Called immediately after the V8 context for a frame has been created. To
  // retrieve the JavaScript 'window' object use the CefV8Context::GetGlobal()
  // method.
  ///
  /*--cef()--*/
  virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefRefPtr<CefV8Context> context) {}

  ///
  // Called immediately before the V8 context for a frame is released. No
  // references to the context should be kept after this method is called.
  ///
  /*--cef()--*/
  virtual void OnContextReleased(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 CefRefPtr<CefV8Context> context) {}

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

  ///
  // Called when a new message is received from a different process. Return true
  // if the message was handled or false otherwise. Do not keep a reference to
  // or attempt to access the message outside of this callback.
  ///
  /*--cef()--*/
  virtual bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                        CefProcessId source_process,
                                        CefRefPtr<CefProcessMessage> message) {
    return false;
  }
};

#endif  // CEF_INCLUDE_CEF_RENDER_PROCESS_HANDLER_H_
