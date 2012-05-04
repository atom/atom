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

#ifndef CEF_INCLUDE_CEF_WEB_PLUGIN_H_
#define CEF_INCLUDE_CEF_WEB_PLUGIN_H_

#include "include/cef_base.h"

class CefWebPluginInfo;

///
// Returns the number of installed web plugins. This method must be called on
// the UI thread.
///
/*--cef()--*/
size_t CefGetWebPluginCount();

///
// Returns information for web plugin at the specified zero-based index. This
// method must be called on the UI thread.
///
/*--cef()--*/
CefRefPtr<CefWebPluginInfo> CefGetWebPluginInfo(int index);

///
// Returns information for web plugin with the specified name. This method must
// be called on the UI thread.
///
/*--cef(capi_name=cef_get_web_plugin_info_byname)--*/
CefRefPtr<CefWebPluginInfo> CefGetWebPluginInfo(const CefString& name);


///
// Information about a specific web plugin.
///
/*--cef(source=library)--*/
class CefWebPluginInfo : public virtual CefBase {
 public:
  ///
  // Returns the plugin name (i.e. Flash).
  ///
  /*--cef()--*/
  virtual CefString GetName() =0;

  ///
  // Returns the plugin file path (DLL/bundle/library).
  ///
  /*--cef()--*/
  virtual CefString GetPath() =0;

  ///
  // Returns the version of the plugin (may be OS-specific).
  ///
  /*--cef()--*/
  virtual CefString GetVersion() =0;

  ///
  // Returns a description of the plugin from the version information.
  ///
  /*--cef()--*/
  virtual CefString GetDescription() =0;
};

#endif  // CEF_INCLUDE_CEF_WEB_PLUGIN_H_
