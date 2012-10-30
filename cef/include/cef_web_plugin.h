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
#include "include/cef_browser.h"

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

///
// Interface to implement for visiting web plugin information. The methods of
// this class will be called on the browser process UI thread.
///
/*--cef(source=client)--*/
class CefWebPluginInfoVisitor : public virtual CefBase {
 public:
  ///
  // Method that will be called once for each plugin. |count| is the 0-based
  // index for the current plugin. |total| is the total number of plugins.
  // Return false to stop visiting plugins. This method may never be called if
  // no plugins are found.
  ///
  /*--cef()--*/
  virtual bool Visit(CefRefPtr<CefWebPluginInfo> info, int count, int total) =0;
};

///
// Visit web plugin information. Can be called on any thread in the browser
// process.
///
/*--cef()--*/
void CefVisitWebPluginInfo(CefRefPtr<CefWebPluginInfoVisitor> visitor);

///
// Cause the plugin list to refresh the next time it is accessed regardless
// of whether it has already been loaded. Can be called on any thread in the
// browser process.
///
/*--cef()--*/
void CefRefreshWebPlugins();

///
// Add a plugin path (directory + file). This change may not take affect until
// after CefRefreshWebPlugins() is called. Can be called on any thread in the
// browser process.
///
/*--cef()--*/
void CefAddWebPluginPath(const CefString& path);

///
// Add a plugin directory. This change may not take affect until after
// CefRefreshWebPlugins() is called. Can be called on any thread in the browser
// process.
///
/*--cef()--*/
void CefAddWebPluginDirectory(const CefString& dir);

///
// Remove a plugin path (directory + file). This change may not take affect
// until after CefRefreshWebPlugins() is called. Can be called on any thread in
// the browser process.
///
/*--cef()--*/
void CefRemoveWebPluginPath(const CefString& path);

///
// Unregister an internal plugin. This may be undone the next time
// CefRefreshWebPlugins() is called. Can be called on any thread in the browser
// process.
///
/*--cef()--*/
void CefUnregisterInternalWebPlugin(const CefString& path);

///
// Force a plugin to shutdown. Can be called on any thread in the browser
// process but will be executed on the IO thread.
///
/*--cef()--*/
void CefForceWebPluginShutdown(const CefString& path);

///
// Register a plugin crash. Can be called on any thread in the browser process
// but will be executed on the IO thread.
///
/*--cef()--*/
void CefRegisterWebPluginCrash(const CefString& path);

///
// Interface to implement for receiving unstable plugin information. The methods
// of this class will be called on the browser process IO thread.
///
/*--cef(source=client)--*/
class CefWebPluginUnstableCallback : public virtual CefBase {
 public:
  ///
  // Method that will be called for the requested plugin. |unstable| will be
  // true if the plugin has reached the crash count threshold of 3 times in 120
  // seconds.
  ///
  /*--cef()--*/
  virtual void IsUnstable(const CefString& path,
                          bool unstable) =0;
};

///
// Query if a plugin is unstable. Can be called on any thread in the browser
// process.
///
/*--cef()--*/
void CefIsWebPluginUnstable(const CefString& path,
                            CefRefPtr<CefWebPluginUnstableCallback> callback);


#endif  // CEF_INCLUDE_CEF_WEB_PLUGIN_H_
