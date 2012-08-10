// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_DOM_EVENT_IMPL_H_
#define CEF_LIBCEF_DOM_EVENT_IMPL_H_
#pragma once

#include "include/cef_dom.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebDOMEvent.h"

class CefDOMDocumentImpl;

class CefDOMEventImpl : public CefDOMEvent {
 public:
  CefDOMEventImpl(CefRefPtr<CefDOMDocumentImpl> document,
                  const WebKit::WebDOMEvent& event);
  virtual ~CefDOMEventImpl();

  // CefDOMEvent methods.
  virtual CefString GetType() OVERRIDE;
  virtual Category GetCategory() OVERRIDE;
  virtual Phase GetPhase() OVERRIDE;
  virtual bool CanBubble() OVERRIDE;
  virtual bool CanCancel() OVERRIDE;
  virtual CefRefPtr<CefDOMDocument> GetDocument() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetTarget() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetCurrentTarget() OVERRIDE;

  // Will be called from CefDOMEventListenerWrapper::handleEvent().
  void Detach();

  // Verify that the object exists and is being accessed on the UI thread.
  bool VerifyContext();

 protected:
  CefRefPtr<CefDOMDocumentImpl> document_;
  WebKit::WebDOMEvent event_;

  IMPLEMENT_REFCOUNTING(CefDOMEventImpl);
};

#endif  // CEF_LIBCEF_DOM_EVENT_IMPL_H_
