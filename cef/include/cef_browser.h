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

#ifndef CEF_INCLUDE_CEF_BROWSER_H_
#define CEF_INCLUDE_CEF_BROWSER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_frame.h"
#include "include/cef_process_message.h"
#include <vector>

class CefBrowserHost;
class CefClient;


///
// Class used to represent a browser window. When used in the browser process
// the methods of this class may be called on any thread unless otherwise
// indicated in the comments. When used in the render process the methods of
// this class may only be called on the main thread.
///
/*--cef(source=library)--*/
class CefBrowser : public virtual CefBase {
 public:
  ///
  // Returns the browser host object. This method can only be called in the
  // browser process.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefBrowserHost> GetHost() =0;

  ///
  // Returns true if the browser can navigate backwards.
  ///
  /*--cef()--*/
  virtual bool CanGoBack() =0;

  ///
  // Navigate backwards.
  ///
  /*--cef()--*/
  virtual void GoBack() =0;

  ///
  // Returns true if the browser can navigate forwards.
  ///
  /*--cef()--*/
  virtual bool CanGoForward() =0;

  ///
  // Navigate forwards.
  ///
  /*--cef()--*/
  virtual void GoForward() =0;

  ///
  // Returns true if the browser is currently loading.
  ///
  /*--cef()--*/
  virtual bool IsLoading() =0;

  ///
  // Reload the current page.
  ///
  /*--cef()--*/
  virtual void Reload() =0;

  ///
  // Reload the current page ignoring any cached data.
  ///
  /*--cef()--*/
  virtual void ReloadIgnoreCache() =0;

  ///
  // Stop loading the page.
  ///
  /*--cef()--*/
  virtual void StopLoad() =0;

  ///
  // Returns the globally unique identifier for this browser.
  ///
  /*--cef()--*/
  virtual int GetIdentifier() =0;

  ///
  // Returns true if the window is a popup window.
  ///
  /*--cef()--*/
  virtual bool IsPopup() =0;

  ///
  // Returns true if a document has been loaded in the browser.
  ///
  /*--cef()--*/
  virtual bool HasDocument() =0;

  ///
  // Returns the main (top-level) frame for the browser window.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetMainFrame() =0;

  ///
  // Returns the focused frame for the browser window.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFocusedFrame() =0;

  ///
  // Returns the frame with the specified identifier, or NULL if not found.
  ///
  /*--cef(capi_name=get_frame_byident)--*/
  virtual CefRefPtr<CefFrame> GetFrame(int64 identifier) =0;

  ///
  // Returns the frame with the specified name, or NULL if not found.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFrame(const CefString& name) =0;

  ///
  // Returns the number of frames that currently exist.
  ///
  /*--cef()--*/
  virtual size_t GetFrameCount() =0;

  ///
  // Returns the identifiers of all existing frames.
  ///
  /*--cef(count_func=identifiers:GetFrameCount)--*/
  virtual void GetFrameIdentifiers(std::vector<int64>& identifiers) =0;

  ///
  // Returns the names of all existing frames.
  ///
  /*--cef()--*/
  virtual void GetFrameNames(std::vector<CefString>& names) =0;

  //
  // Send a message to the specified |target_process|. Returns true if the
  // message was sent successfully.
  ///
  /*--cef()--*/
  virtual bool SendProcessMessage(CefProcessId target_process,
                                  CefRefPtr<CefProcessMessage> message) =0;
};


///
// Callback interface for CefBrowserHost::RunFileDialog. The methods of this
// class will be called on the browser process UI thread.
///
/*--cef(source=client)--*/
class CefRunFileDialogCallback : public virtual CefBase {
 public:
  ///
  // Called asynchronously after the file dialog is dismissed. If the selection
  // was successful |file_paths| will be a single value or a list of values
  // depending on the dialog mode. If the selection was cancelled |file_paths|
  // will be empty.
  ///
  /*--cef(capi_name=cont)--*/
  virtual void OnFileDialogDismissed(
      CefRefPtr<CefBrowserHost> browser_host,
      const std::vector<CefString>& file_paths) =0;
};


///
// Class used to represent the browser process aspects of a browser window. The
// methods of this class can only be called in the browser process. They may be
// called on any thread in that process unless otherwise indicated in the
// comments.
///
/*--cef(source=library)--*/
class CefBrowserHost : public virtual CefBase {
 public:
  typedef cef_file_dialog_mode_t FileDialogMode;

  ///
  // Create a new browser window using the window parameters specified by
  // |windowInfo|. All values will be copied internally and the actual window
  // will be created on the UI thread. This method can be called on any browser
  // process thread and will not block.
  ///
  /*--cef(optional_param=url)--*/
  static bool CreateBrowser(const CefWindowInfo& windowInfo,
                            CefRefPtr<CefClient> client,
                            const CefString& url,
                            const CefBrowserSettings& settings);

  ///
  // Create a new browser window using the window parameters specified by
  // |windowInfo|. This method can only be called on the browser process UI
  // thread.
  ///
  /*--cef(optional_param=url)--*/
  static CefRefPtr<CefBrowser> CreateBrowserSync(
      const CefWindowInfo& windowInfo,
      CefRefPtr<CefClient> client,
      const CefString& url,
      const CefBrowserSettings& settings);

  ///
  // Returns the hosted browser object.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefBrowser> GetBrowser() =0;
  
  ///
  // Call this method before destroying a contained browser window. This method
  // performs any internal cleanup that may be needed before the browser window
  // is destroyed.
  ///
  /*--cef()--*/
  virtual void ParentWindowWillClose() =0;

  ///
  // Closes this browser window.
  ///
  /*--cef()--*/
  virtual void CloseBrowser() =0;

  ///
  // Set focus for the browser window. If |enable| is true focus will be set to
  // the window. Otherwise, focus will be removed.
  ///
  /*--cef()--*/
  virtual void SetFocus(bool enable) =0;

  ///
  // Retrieve the window handle for this browser.
  ///
  /*--cef()--*/
  virtual CefWindowHandle GetWindowHandle() =0;

  ///
  // Retrieve the window handle of the browser that opened this browser. Will
  // return NULL for non-popup windows. This method can be used in combination
  // with custom handling of modal windows.
  ///
  /*--cef()--*/
  virtual CefWindowHandle GetOpenerWindowHandle() =0;

  ///
  // Returns the client for this browser.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefClient> GetClient() =0;

  ///
  // Returns the DevTools URL for this browser. If |http_scheme| is true the
  // returned URL will use the http scheme instead of the chrome-devtools
  // scheme. Remote debugging can be enabled by specifying the
  // "remote-debugging-port" command-line flag or by setting the
  // CefSettings.remote_debugging_port value. If remote debugging is not enabled
  // this method will return an empty string.
  ///
  /*--cef()--*/
  virtual CefString GetDevToolsURL(bool http_scheme) =0;

  ///
  // Get the current zoom level. The default zoom level is 0.0. This method can
  // only be called on the UI thread.
  ///
  /*--cef()--*/
  virtual double GetZoomLevel() =0;

  ///
  // Change the zoom level to the specified value. Specify 0.0 to reset the
  // zoom level. If called on the UI thread the change will be applied
  // immediately. Otherwise, the change will be applied asynchronously on the
  // UI thread.
  ///
  /*--cef()--*/
  virtual void SetZoomLevel(double zoomLevel) =0;

  ///
  // Call to run a file chooser dialog. Only a single file chooser dialog may be
  // pending at any given time. |mode| represents the type of dialog to display.
  // |title| to the title to be used for the dialog and may be empty to show the
  // default title ("Open" or "Save" depending on the mode). |default_file_name|
  // is the default file name to select in the dialog. |accept_types| is a list
  // of valid lower-cased MIME types or file extensions specified in an input
  // element and is used to restrict selectable files to such types. |callback|
  // will be executed after the dialog is dismissed or immediately if another
  // dialog is already pending. The dialog will be initiated asynchronously on
  // the UI thread.
  ///
  /*--cef(optional_param=title,optional_param=default_file_name,
          optional_param=accept_types)--*/
  virtual void RunFileDialog(FileDialogMode mode,
                             const CefString& title,
                             const CefString& default_file_name,
                             const std::vector<CefString>& accept_types,
                             CefRefPtr<CefRunFileDialogCallback> callback) =0;
};

#endif  // CEF_INCLUDE_CEF_BROWSER_H_
