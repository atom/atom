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

#ifndef CEF_INCLUDE_CEF_BROWSER_H_
#define CEF_INCLUDE_CEF_BROWSER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_frame.h"
#include <vector>

class CefClient;

///
// Class used to represent a browser window. The methods of this class may be
// called on any thread unless otherwise indicated in the comments.
///
/*--cef(source=library)--*/
class CefBrowser : public virtual CefBase {
 public:
  typedef cef_key_type_t KeyType;
  typedef cef_mouse_button_type_t MouseButtonType;
  typedef cef_paint_element_type_t PaintElementType;

  ///
  // Create a new browser window using the window parameters specified by
  // |windowInfo|. All values will be copied internally and the actual window
  // will be created on the UI thread. This method call will not block.
  ///
  /*--cef(optional_param=url)--*/
  static bool CreateBrowser(CefWindowInfo& windowInfo,
                            CefRefPtr<CefClient> client,
                            const CefString& url,
                            const CefBrowserSettings& settings);

  ///
  // Create a new browser window using the window parameters specified by
  // |windowInfo|. This method should only be called on the UI thread.
  ///
  /*--cef(optional_param=url)--*/
  static CefRefPtr<CefBrowser> CreateBrowserSync(CefWindowInfo& windowInfo,
                                            CefRefPtr<CefClient> client,
                                            const CefString& url,
                                            const CefBrowserSettings& settings);

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
  // Returns true if the window is a popup window.
  ///
  /*--cef()--*/
  virtual bool IsPopup() =0;

  // Returns true if a document has been loaded in the browser.
  /*--cef()--*/
  virtual bool HasDocument() =0;

  ///
  // Returns the client for this browser.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefClient> GetClient() =0;

  ///
  // Returns the main (top-level) frame for the browser window.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetMainFrame() =0;

  ///
  // Returns the focused frame for the browser window. This method should only
  // be called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFocusedFrame() =0;

  ///
  // Returns the frame with the specified name, or NULL if not found. This
  // method should only be called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFrame(const CefString& name) =0;

  ///
  // Returns the names of all existing frames. This method should only be called
  // on the UI thread.
  ///
  /*--cef()--*/
  virtual void GetFrameNames(std::vector<CefString>& names) =0;

  ///
  // Search for |searchText|. |identifier| can be used to have multiple searches
  // running simultaniously. |forward| indicates whether to search forward or
  // backward within the page. |matchCase| indicates whether the search should
  // be case-sensitive. |findNext| indicates whether this is the first request
  // or a follow-up.
  ///
  /*--cef()--*/
  virtual void Find(int identifier, const CefString& searchText,
                    bool forward, bool matchCase, bool findNext) =0;

  ///
  // Cancel all searches that are currently going on.
  ///
  /*--cef()--*/
  virtual void StopFinding(bool clearSelection) =0;

  ///
  // Get the zoom level.
  ///
  /*--cef()--*/
  virtual double GetZoomLevel() =0;

  ///
  // Change the zoom level to the specified value.
  ///
  /*--cef()--*/
  virtual void SetZoomLevel(double zoomLevel) =0;

  ///
  // Clear the back/forward browsing history.
  ///
  /*--cef()--*/
  virtual void ClearHistory() =0;

  ///
  // Open developer tools in its own window.
  ///
  /*--cef()--*/
  virtual void ShowDevTools() =0;

  ///
  // Explicitly close the developer tools window if one exists for this browser
  // instance.
  ///
  /*--cef()--*/
  virtual void CloseDevTools() =0;

  ///
  // Returns true if window rendering is disabled.
  ///
  /*--cef()--*/
  virtual bool IsWindowRenderingDisabled() =0;

  ///
  // Get the size of the specified element. This method should only be called on
  // the UI thread.
  ///
  /*--cef()--*/
  virtual bool GetSize(PaintElementType type, int& width, int& height) =0;

  ///
  // Set the size of the specified element. This method is only used when window
  // rendering is disabled.
  ///
  /*--cef()--*/
  virtual void SetSize(PaintElementType type, int width, int height) =0;

  ///
  // Returns true if a popup is currently visible. This method should only be
  // called on the UI thread.
  ///
  /*--cef()--*/
  virtual bool IsPopupVisible() =0;

  ///
  // Hide the currently visible popup, if any.
  ///
  /*--cef()--*/
  virtual void HidePopup() =0;

  ///
  // Invalidate the |dirtyRect| region of the view. This method is only used
  // when window rendering is disabled and will result in a call to
  // HandlePaint().
  ///
  /*--cef()--*/
  virtual void Invalidate(const CefRect& dirtyRect) =0;

  ///
  // Get the raw image data contained in the specified element without
  // performing validation. The specified |width| and |height| dimensions must
  // match the current element size. On Windows |buffer| must be width*height*4
  // bytes in size and represents a BGRA image with an upper-left origin. This
  // method should only be called on the UI thread.
  ///
  /*--cef()--*/
  virtual bool GetImage(PaintElementType type, int width, int height,
                        void* buffer) =0;

  ///
  // Send a key event to the browser.
  ///
  /*--cef()--*/
  virtual void SendKeyEvent(KeyType type, int key, int modifiers, bool sysChar,
                            bool imeChar) =0;

  ///
  // Send a mouse click event to the browser. The |x| and |y| coordinates are
  // relative to the upper-left corner of the view.
  ///
  /*--cef()--*/
  virtual void SendMouseClickEvent(int x, int y, MouseButtonType type,
                                   bool mouseUp, int clickCount) =0;

  ///
  // Send a mouse move event to the browser. The |x| and |y| coordinates are
  // relative to the upper-left corner of the view.
  ///
  /*--cef()--*/
  virtual void SendMouseMoveEvent(int x, int y, bool mouseLeave) =0;

  ///
  // Send a mouse wheel event to the browser. The |x| and |y| coordinates are
  // relative to the upper-left corner of the view.
  ///
  /*--cef()--*/
  virtual void SendMouseWheelEvent(int x, int y, int delta) =0;

  ///
  // Send a focus event to the browser.
  ///
  /*--cef()--*/
  virtual void SendFocusEvent(bool setFocus) =0;

  ///
  // Send a capture lost event to the browser.
  ///
  /*--cef()--*/
  virtual void SendCaptureLostEvent() =0;
};

#endif  // CEF_INCLUDE_CEF_BROWSER_H_
