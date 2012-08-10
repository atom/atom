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

#ifndef CEF_INCLUDE_CEF_XML_READER_H_
#define CEF_INCLUDE_CEF_XML_READER_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_stream.h"

///
// Class that supports the reading of XML data via the libxml streaming API.
// The methods of this class should only be called on the thread that creates
// the object.
///
/*--cef(source=library)--*/
class CefXmlReader : public virtual CefBase {
 public:
  typedef cef_xml_encoding_type_t EncodingType;
  typedef cef_xml_node_type_t NodeType;

  ///
  // Create a new CefXmlReader object. The returned object's methods can only
  // be called from the thread that created the object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefXmlReader> Create(CefRefPtr<CefStreamReader> stream,
                                        EncodingType encodingType,
                                        const CefString& URI);

  ///
  // Moves the cursor to the next node in the document. This method must be
  // called at least once to set the current cursor position. Returns true if
  // the cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToNextNode() =0;

  ///
  // Close the document. This should be called directly to ensure that cleanup
  // occurs on the correct thread.
  ///
  /*--cef()--*/
  virtual bool Close() =0;

  ///
  // Returns true if an error has been reported by the XML parser.
  ///
  /*--cef()--*/
  virtual bool HasError() =0;

  ///
  // Returns the error string.
  ///
  /*--cef()--*/
  virtual CefString GetError() =0;


  // The below methods retrieve data for the node at the current cursor
  // position.

  ///
  // Returns the node type.
  ///
  /*--cef(default_retval=XML_NODE_UNSUPPORTED)--*/
  virtual NodeType GetType() =0;

  ///
  // Returns the node depth. Depth starts at 0 for the root node.
  ///
  /*--cef()--*/
  virtual int GetDepth() =0;

  ///
  // Returns the local name. See
  // http://www.w3.org/TR/REC-xml-names/#NT-LocalPart for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetLocalName() =0;

  ///
  // Returns the namespace prefix. See http://www.w3.org/TR/REC-xml-names/ for
  // additional details.
  ///
  /*--cef()--*/
  virtual CefString GetPrefix() =0;

  ///
  // Returns the qualified name, equal to (Prefix:)LocalName. See
  // http://www.w3.org/TR/REC-xml-names/#ns-qualnames for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetQualifiedName() =0;

  ///
  // Returns the URI defining the namespace associated with the node. See
  // http://www.w3.org/TR/REC-xml-names/ for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetNamespaceURI() =0;

  ///
  // Returns the base URI of the node. See http://www.w3.org/TR/xmlbase/ for
  // additional details.
  ///
  /*--cef()--*/
  virtual CefString GetBaseURI() =0;

  ///
  // Returns the xml:lang scope within which the node resides. See
  // http://www.w3.org/TR/REC-xml/#sec-lang-tag for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetXmlLang() =0;

  ///
  // Returns true if the node represents an empty element. <a/> is considered
  // empty but <a></a> is not.
  ///
  /*--cef()--*/
  virtual bool IsEmptyElement() =0;

  ///
  // Returns true if the node has a text value.
  ///
  /*--cef()--*/
  virtual bool HasValue() =0;

  ///
  // Returns the text value.
  ///
  /*--cef()--*/
  virtual CefString GetValue() =0;

  ///
  // Returns true if the node has attributes.
  ///
  /*--cef()--*/
  virtual bool HasAttributes() =0;

  ///
  // Returns the number of attributes.
  ///
  /*--cef()--*/
  virtual size_t GetAttributeCount() =0;

  ///
  // Returns the value of the attribute at the specified 0-based index.
  ///
  /*--cef(capi_name=get_attribute_byindex,index_param=index)--*/
  virtual CefString GetAttribute(int index) =0;

  ///
  // Returns the value of the attribute with the specified qualified name.
  ///
  /*--cef(capi_name=get_attribute_byqname)--*/
  virtual CefString GetAttribute(const CefString& qualifiedName) =0;

  ///
  // Returns the value of the attribute with the specified local name and
  // namespace URI.
  ///
  /*--cef(capi_name=get_attribute_bylname)--*/
  virtual CefString GetAttribute(const CefString& localName,
                                 const CefString& namespaceURI) =0;

  ///
  // Returns an XML representation of the current node's children.
  ///
  /*--cef()--*/
  virtual CefString GetInnerXml() =0;

  ///
  // Returns an XML representation of the current node including its children.
  ///
  /*--cef()--*/
  virtual CefString GetOuterXml() =0;

  ///
  // Returns the line number for the current node.
  ///
  /*--cef()--*/
  virtual int GetLineNumber() =0;


  // Attribute nodes are not traversed by default. The below methods can be
  // used to move the cursor to an attribute node. MoveToCarryingElement() can
  // be called afterwards to return the cursor to the carrying element. The
  // depth of an attribute node will be 1 + the depth of the carrying element.

  ///
  // Moves the cursor to the attribute at the specified 0-based index. Returns
  // true if the cursor position was set successfully.
  ///
  /*--cef(capi_name=move_to_attribute_byindex,index_param=index)--*/
  virtual bool MoveToAttribute(int index) =0;

  ///
  // Moves the cursor to the attribute with the specified qualified name.
  // Returns true if the cursor position was set successfully.
  ///
  /*--cef(capi_name=move_to_attribute_byqname)--*/
  virtual bool MoveToAttribute(const CefString& qualifiedName) =0;

  ///
  // Moves the cursor to the attribute with the specified local name and
  // namespace URI. Returns true if the cursor position was set successfully.
  ///
  /*--cef(capi_name=move_to_attribute_bylname)--*/
  virtual bool MoveToAttribute(const CefString& localName,
                               const CefString& namespaceURI) =0;

  ///
  // Moves the cursor to the first attribute in the current element. Returns
  // true if the cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToFirstAttribute() =0;

  ///
  // Moves the cursor to the next attribute in the current element. Returns
  // true if the cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToNextAttribute() =0;

  ///
  // Moves the cursor back to the carrying element. Returns true if the cursor
  // position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToCarryingElement() =0;
};

#endif  // CEF_INCLUDE_CEF_XML_READER_H_
