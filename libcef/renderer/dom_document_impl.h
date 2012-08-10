// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_DOM_DOCUMENT_IMPL_H_
#define CEF_LIBCEF_DOM_DOCUMENT_IMPL_H_
#pragma once

#include <map>
#include "include/cef_dom.h"

namespace WebKit {
class WebFrame;
class WebNode;
};

class CefBrowserImpl;

class CefDOMDocumentImpl : public CefDOMDocument {
 public:
  CefDOMDocumentImpl(CefBrowserImpl* browser,
                     WebKit::WebFrame* frame);
  virtual ~CefDOMDocumentImpl();

  // CefDOMDocument methods.
  virtual Type GetType() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetDocument() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetBody() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetHead() OVERRIDE;
  virtual CefString GetTitle() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetElementById(const CefString& id) OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetFocusedNode() OVERRIDE;
  virtual bool HasSelection() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetSelectionStartNode() OVERRIDE;
  virtual int GetSelectionStartOffset() OVERRIDE;
  virtual CefRefPtr<CefDOMNode> GetSelectionEndNode() OVERRIDE;
  virtual int GetSelectionEndOffset() OVERRIDE;
  virtual CefString GetSelectionAsMarkup() OVERRIDE;
  virtual CefString GetSelectionAsText() OVERRIDE;
  virtual CefString GetBaseURL() OVERRIDE;
  virtual CefString GetCompleteURL(const CefString& partialURL) OVERRIDE;

  CefBrowserImpl* GetBrowser() { return browser_; }
  WebKit::WebFrame* GetFrame() { return frame_; }

  // The document maintains a map of all existing node objects.
  CefRefPtr<CefDOMNode> GetOrCreateNode(const WebKit::WebNode& node);
  void RemoveNode(const WebKit::WebNode& node);

  // Must be called before the object is destroyed.
  void Detach();

  // Verify that the object exists and is being accessed on the UI thread.
  bool VerifyContext();

 protected:
  CefBrowserImpl* browser_;
  WebKit::WebFrame* frame_;

  typedef std::map<WebKit::WebNode, CefDOMNode*> NodeMap;
  NodeMap node_map_;

  IMPLEMENT_REFCOUNTING(CefDOMDocumentImpl);
};

#endif  // CEF_LIBCEF_DOM_DOCUMENT_IMPL_H_
