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


#ifndef CEF_INCLUDE_CEF_APP_H_
#define CEF_INCLUDE_CEF_APP_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_proxy_handler.h"
#include "include/cef_resource_bundle_handler.h"

class CefApp;

///
// This function should be called on the main application thread to initialize
// CEF when the application is started. The |application| parameter may be
// empty. A return value of true indicates that it succeeded and false indicates
// that it failed.
///
/*--cef(revision_check,optional_param=application)--*/
bool CefInitialize(const CefSettings& settings, CefRefPtr<CefApp> application);

///
// This function should be called on the main application thread to shut down
// CEF before the application exits.
///
/*--cef()--*/
void CefShutdown();

///
// Perform a single iteration of CEF message loop processing. This function is
// used to integrate the CEF message loop into an existing application message
// loop. Care must be taken to balance performance against excessive CPU usage.
// This function should only be called on the main application thread and only
// if CefInitialize() is called with a CefSettings.multi_threaded_message_loop
// value of false. This function will not block.
///
/*--cef()--*/
void CefDoMessageLoopWork();

///
// Run the CEF message loop. Use this function instead of an application-
// provided message loop to get the best balance between performance and CPU
// usage. This function should only be called on the main application thread and
// only if CefInitialize() is called with a
// CefSettings.multi_threaded_message_loop value of false. This function will
// block until a quit message is received by the system.
///
/*--cef()--*/
void CefRunMessageLoop();

///
// Quit the CEF message loop that was started by calling CefRunMessageLoop().
// This function should only be called on the main application thread and only
// if CefRunMessageLoop() was used.
///
/*--cef()--*/
void CefQuitMessageLoop();


///
// Implement this interface to provide handler implementations. Methods will be
// called on the thread indicated.
///
/*--cef(source=client,no_debugct_check)--*/
class CefApp : public virtual CefBase {
 public:
  ///
  // Return the handler for resource bundle events. If
  // CefSettings.pack_loading_disabled is true a handler must be returned. If no
  // handler is returned resources will be loaded from pack files. This method
  // is called on multiple threads.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefResourceBundleHandler> GetResourceBundleHandler() {
    return NULL;
  }

  ///
  // Return the handler for proxy events. If not handler is returned the default
  // system handler will be used. This method is called on the IO thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefProxyHandler> GetProxyHandler() {
    return NULL;
  }
};

#endif  // CEF_INCLUDE_CEF_APP_H_
