// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_XML_READER_IMPL_H_
#define CEF_LIBCEF_BROWSER_XML_READER_IMPL_H_
#pragma once

#include <libxml/xmlreader.h>
#include <sstream>

#include "include/cef_xml_reader.h"
#include "base/threading/platform_thread.h"

// Implementation of CefXmlReader
class CefXmlReaderImpl : public CefXmlReader {
 public:
  CefXmlReaderImpl();
  ~CefXmlReaderImpl();

  // Initialize the reader context.
  bool Initialize(CefRefPtr<CefStreamReader> stream,
                  EncodingType encodingType, const CefString& URI);

  virtual bool MoveToNextNode() OVERRIDE;
  virtual bool Close() OVERRIDE;
  virtual bool HasError() OVERRIDE;
  virtual CefString GetError() OVERRIDE;
  virtual NodeType GetType() OVERRIDE;
  virtual int GetDepth() OVERRIDE;
  virtual CefString GetLocalName() OVERRIDE;
  virtual CefString GetPrefix() OVERRIDE;
  virtual CefString GetQualifiedName() OVERRIDE;
  virtual CefString GetNamespaceURI() OVERRIDE;
  virtual CefString GetBaseURI() OVERRIDE;
  virtual CefString GetXmlLang() OVERRIDE;
  virtual bool IsEmptyElement() OVERRIDE;
  virtual bool HasValue() OVERRIDE;
  virtual CefString GetValue() OVERRIDE;
  virtual bool HasAttributes() OVERRIDE;
  virtual size_t GetAttributeCount() OVERRIDE;
  virtual CefString GetAttribute(int index) OVERRIDE;
  virtual CefString GetAttribute(const CefString& qualifiedName) OVERRIDE;
  virtual CefString GetAttribute(const CefString& localName,
                                 const CefString& namespaceURI) OVERRIDE;
  virtual CefString GetInnerXml() OVERRIDE;
  virtual CefString GetOuterXml() OVERRIDE;
  virtual int GetLineNumber() OVERRIDE;
  virtual bool MoveToAttribute(int index) OVERRIDE;
  virtual bool MoveToAttribute(const CefString& qualifiedName) OVERRIDE;
  virtual bool MoveToAttribute(const CefString& localName,
                               const CefString& namespaceURI) OVERRIDE;
  virtual bool MoveToFirstAttribute() OVERRIDE;
  virtual bool MoveToNextAttribute() OVERRIDE;
  virtual bool MoveToCarryingElement() OVERRIDE;

  // Add another line to the error string.
  void AppendError(const CefString& error_str);

  // Verify that the reader exists and is being accessed from the correct
  // thread.
  bool VerifyContext();

 protected:
  base::PlatformThreadId supported_thread_id_;
  CefRefPtr<CefStreamReader> stream_;
  xmlTextReaderPtr reader_;
  std::stringstream error_buf_;

  IMPLEMENT_REFCOUNTING(CefXMLReaderImpl);
};

#endif  // CEF_LIBCEF_BROWSER_XML_READER_IMPL_H_
