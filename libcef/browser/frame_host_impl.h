// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_FRAME_HOST_IMPL_H_
#define CEF_LIBCEF_BROWSER_FRAME_HOST_IMPL_H_
#pragma once

#include <string>
#include "include/cef_frame.h"
#include "base/synchronization/lock.h"

class CefBrowserHostImpl;

// Implementation of CefFrame. CefFrameHostImpl objects are owned by the
// CefBrowerHostImpl and will be detached when the browser is notified that the
// associated renderer WebFrame will close.
class CefFrameHostImpl : public CefFrame {
 public:
  CefFrameHostImpl(CefBrowserHostImpl* browser,
               int64 frame_id,
               bool is_main_frame);
  virtual ~CefFrameHostImpl();

  // CefFrame methods
  virtual bool IsValid() OVERRIDE;
  virtual void Undo() OVERRIDE;
  virtual void Redo() OVERRIDE;
  virtual void Cut() OVERRIDE;
  virtual void Copy() OVERRIDE;
  virtual void Paste() OVERRIDE;
  virtual void Delete() OVERRIDE;
  virtual void SelectAll() OVERRIDE;
  virtual void ViewSource() OVERRIDE;
  virtual void GetSource(CefRefPtr<CefStringVisitor> visitor) OVERRIDE;
  virtual void GetText(CefRefPtr<CefStringVisitor> visitor) OVERRIDE;
  virtual void LoadRequest(CefRefPtr<CefRequest> request) OVERRIDE;
  virtual void LoadURL(const CefString& url) OVERRIDE;
  virtual void LoadString(const CefString& string,
                          const CefString& url) OVERRIDE;
  virtual void ExecuteJavaScript(const CefString& jsCode,
                                 const CefString& scriptUrl,
                                 int startLine) OVERRIDE;
  virtual bool IsMain() OVERRIDE;
  virtual bool IsFocused() OVERRIDE;
  virtual CefString GetName() OVERRIDE;
  virtual int64 GetIdentifier() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetParent() OVERRIDE;
  virtual CefString GetURL() OVERRIDE;
  virtual CefRefPtr<CefBrowser> GetBrowser() OVERRIDE;
  virtual CefRefPtr<CefV8Context> GetV8Context() OVERRIDE;
  virtual void VisitDOM(CefRefPtr<CefDOMVisitor> visitor) OVERRIDE;

  void SetFocused(bool focused);
  void SetURL(const CefString& url);
  void SetName(const CefString& name);
  void SetParentId(int64 frame_id);

  // Detach the frame from the browser.
  void Detach();

  // kMainFrameId must be -1 to align with renderer expectations.
  static const int64 kMainFrameId = -1;
  static const int64 kFocusedFrameId = -2;
  static const int64 kUnspecifiedFrameId = -3;
  static const int64 kInvalidFrameId = -4;

 protected:
  int64 frame_id_;
  bool is_main_frame_;

  // Volatile state information. All access must be protected by the state lock.
  base::Lock state_lock_;
  CefBrowserHostImpl* browser_;
  bool is_focused_;
  CefString url_;
  CefString name_;
  int64 parent_frame_id_;

  IMPLEMENT_REFCOUNTING(CefFrameHostImpl);
  DISALLOW_EVIL_CONSTRUCTORS(CefFrameHostImpl);
};

#endif  // CEF_LIBCEF_BROWSER_FRAME_HOST_IMPL_H_
