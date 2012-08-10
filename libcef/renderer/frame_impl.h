// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_RENDERER_FRAME_IMPL_H_
#define CEF_LIBCEF_RENDERER_FRAME_IMPL_H_
#pragma once

#include <string>
#include "include/cef_frame.h"
#include "include/cef_v8.h"

class CefBrowserImpl;

namespace WebKit {
class WebFrame;
}

// Implementation of CefFrame. CefFrameImpl objects are owned by the
// CefBrowerImpl and will be detached when the browser is notified that the
// associated renderer WebFrame will close.
class CefFrameImpl : public CefFrame {
 public:
  CefFrameImpl(CefBrowserImpl* browser,
               WebKit::WebFrame* frame);
  virtual ~CefFrameImpl();

  // CefFrame implementation.
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

  void Detach();

  WebKit::WebFrame* web_frame() const { return frame_; }

 protected:
  CefBrowserImpl* browser_;
  WebKit::WebFrame* frame_;
  int64 frame_id_;

  IMPLEMENT_REFCOUNTING(CefFrameImpl);
  DISALLOW_EVIL_CONSTRUCTORS(CefFrameImpl);
};

#endif  // CEF_LIBCEF_RENDERER_FRAME_IMPL_H_
