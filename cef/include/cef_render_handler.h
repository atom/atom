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

#ifndef CEF_INCLUDE_CEF_RENDER_HANDLER_H_
#define CEF_INCLUDE_CEF_RENDER_HANDLER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include <vector>

///
// Implement this interface to handle events when window rendering is disabled.
// The methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefRenderHandler : public virtual CefBase {
 public:
  typedef cef_paint_element_type_t PaintElementType;
  typedef std::vector<CefRect> RectList;

  ///
  // Called to retrieve the view rectangle which is relative to screen
  // coordinates. Return true if the rectangle was provided.
  ///
  /*--cef()--*/
  virtual bool GetViewRect(CefRefPtr<CefBrowser> browser,
                           CefRect& rect) { return false; }

  ///
  // Called to retrieve the simulated screen rectangle. Return true if the
  // rectangle was provided.
  ///
  /*--cef()--*/
  virtual bool GetScreenRect(CefRefPtr<CefBrowser> browser,
                             CefRect& rect) { return false; }

  ///
  // Called to retrieve the translation from view coordinates to actual screen
  // coordinates. Return true if the screen coordinates were provided.
  ///
  /*--cef()--*/
  virtual bool GetScreenPoint(CefRefPtr<CefBrowser> browser,
                              int viewX,
                              int viewY,
                              int& screenX,
                              int& screenY) { return false; }

  ///
  // Called when the browser wants to show or hide the popup widget. The popup
  // should be shown if |show| is true and hidden if |show| is false.
  ///
  /*--cef()--*/
  virtual void OnPopupShow(CefRefPtr<CefBrowser> browser,
                           bool show) {}

  ///
  // Called when the browser wants to move or resize the popup widget. |rect|
  // contains the new location and size.
  ///
  /*--cef()--*/
  virtual void OnPopupSize(CefRefPtr<CefBrowser> browser,
                           const CefRect& rect) {}

  ///
  // Called when an element should be painted. |type| indicates whether the
  // element is the view or the popup widget. |buffer| contains the pixel data
  // for the whole image. |dirtyRects| contains the set of rectangles that need
  // to be repainted. On Windows |buffer| will be width*height*4 bytes in size
  // and represents a BGRA image with an upper-left origin.
  ///
  /*--cef()--*/
  virtual void OnPaint(CefRefPtr<CefBrowser> browser,
                       PaintElementType type,
                       const RectList& dirtyRects,
                       const void* buffer) {}

  ///
  // Called when the browser window's cursor has changed.
  ///
  /*--cef()--*/
  virtual void OnCursorChange(CefRefPtr<CefBrowser> browser,
                              CefCursorHandle cursor) {}
};

#endif  // CEF_INCLUDE_CEF_RENDER_HANDLER_H_
