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
// The contents of this file are only available to applications that link
// against the libcef_dll_wrapper target.
//

#ifndef CEF_INCLUDE_WRAPPER_CEF_XML_OBJECT_H_
#define CEF_INCLUDE_WRAPPER_CEF_XML_OBJECT_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_xml_reader.h"
#include <map>
#include <vector>

class CefStreamReader;

///
// Thread safe class for representing XML data as a structured object. This
// class should not be used with large XML documents because all data will be
// resident in memory at the same time. This implementation supports a
// restricted set of XML features:
// <pre>
// (1) Processing instructions, whitespace and comments are ignored.
// (2) Elements and attributes must always be referenced using the fully
//     qualified name (ie, namespace:localname).
// (3) Empty elements (<a/>) and elements with zero-length values (<a></a>)
//     are considered the same.
// (4) Element nodes are considered part of a value if:
//     (a) The element node follows a non-element node at the same depth
//         (see 5), or
//     (b) The element node does not have a namespace and the parent node does.
// (5) Mixed node types at the same depth are combined into a single element
//     value as follows:
//     (a) All node values are concatenated to form a single string value.
//     (b) Entity reference nodes are resolved to the corresponding entity
//         value.
//     (c) Element nodes are represented by their outer XML string.
// </pre>
///
class CefXmlObject : public CefBase {
 public:
  typedef std::vector<CefRefPtr<CefXmlObject> > ObjectVector;
  typedef std::map<CefString, CefString > AttributeMap;

  ///
  // Create a new object with the specified name. An object name must always be
  // at least one character long.
  ///
  explicit CefXmlObject(const CefString& name);
  virtual ~CefXmlObject();

  ///
  // Load the contents of the specified XML stream into this object.  The
  // existing children and attributes, if any, will first be cleared.
  ///
  bool Load(CefRefPtr<CefStreamReader> stream,
            CefXmlReader::EncodingType encodingType,
            const CefString& URI, CefString* loadError);

  ///
  // Set the name, children and attributes of this object to a duplicate of the
  // specified object's contents. The existing children and attributes, if any,
  // will first be cleared.
  ///
  void Set(CefRefPtr<CefXmlObject> object);

  ///
  // Append a duplicate of the children and attributes of the specified object
  // to this object. If |overwriteAttributes| is true then any attributes in
  // this object that also exist in the specified object will be overwritten
  // with the new values. The name of this object is not changed.
  ///
  void Append(CefRefPtr<CefXmlObject> object, bool overwriteAttributes);

  ///
  // Return a new object with the same name, children and attributes as this
  // object. The parent of the new object will be NULL.
  ///
  CefRefPtr<CefXmlObject> Duplicate();

  ///
  // Clears this object's children and attributes. The name and parenting of
  // this object are not changed.
  ///
  void Clear();

  ///
  // Access the object's name. An object name must always be at least one
  // character long.
  ///
  CefString GetName();
  bool SetName(const CefString& name);

  ///
  // Access the object's parent. The parent can be NULL if this object has not
  // been added as the child on another object.
  ///
  bool HasParent();
  CefRefPtr<CefXmlObject> GetParent();

  ///
  // Access the object's value. An object cannot have a value if it also has
  // children. Attempting to set the value while children exist will fail.
  ///
  bool HasValue();
  CefString GetValue();
  bool SetValue(const CefString& value);

  ///
  // Access the object's attributes. Attributes must have unique names.
  ///
  bool HasAttributes();
  size_t GetAttributeCount();
  bool HasAttribute(const CefString& name);
  CefString GetAttributeValue(const CefString& name);
  bool SetAttributeValue(const CefString& name, const CefString& value);
  size_t GetAttributes(AttributeMap& attributes);
  void ClearAttributes();

  ///
  // Access the object's children. Each object can only have one parent so
  // attempting to add an object that already has a parent will fail. Removing a
  // child will set the child's parent to NULL. Adding a child will set the
  // child's parent to this object. This object's value, if any, will be cleared
  // if a child is added.
  ///
  bool HasChildren();
  size_t GetChildCount();
  bool HasChild(CefRefPtr<CefXmlObject> child);
  bool AddChild(CefRefPtr<CefXmlObject> child);
  bool RemoveChild(CefRefPtr<CefXmlObject> child);
  size_t GetChildren(ObjectVector& children);
  void ClearChildren();

  ///
  // Find the first child with the specified name.
  ///
  CefRefPtr<CefXmlObject> FindChild(const CefString& name);

  ///
  // Find all children with the specified name.
  ///
  size_t FindChildren(const CefString& name, ObjectVector& children);

 private:
  void SetParent(CefXmlObject* parent);

  CefString name_;
  CefXmlObject* parent_;
  CefString value_;
  AttributeMap attributes_;
  ObjectVector children_;

  IMPLEMENT_REFCOUNTING(CefXmlObject);
  IMPLEMENT_LOCKING(CefXmlObject);
};

#endif  // CEF_INCLUDE_WRAPPER_CEF_XML_OBJECT_H_
