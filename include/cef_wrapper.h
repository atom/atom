// Copyright (c) 2010 Marshall A. Greenblatt. All rights reserved.
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

#ifndef _CEF_WRAPPER_H
#define _CEF_WRAPPER_H

#include "cef.h"
#include <map>
#include <vector>

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
class CefXmlObject : public CefBase
{
public:
  typedef std::vector<CefRefPtr<CefXmlObject> > ObjectVector;
  typedef std::map<CefString, CefString > AttributeMap;

  ///
  // Create a new object with the specified name. An object name must always be
  // at least one character long.
  ///
  CefXmlObject(const CefString& name);
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


///
// Thread safe implementation of the CefReadHandler class for reading an
// in-memory array of bytes.
///
class CefByteReadHandler : public CefReadHandler
{
public:
  ///
  // Create a new object for reading an array of bytes. An optional |source|
  // reference can be kept to keep the underlying data source from being
  // released while the reader exists.
  ///
  CefByteReadHandler(const unsigned char* bytes, size_t size,
                     CefRefPtr<CefBase> source);

  ///
  // Read raw binary data.
  ///
  virtual size_t Read(void* ptr, size_t size, size_t n);

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET.
  ///
  virtual int Seek(long offset, int whence);

  ///
  // Return the current offset position.
  ///
  virtual long Tell();

  ///
  // Return non-zero if at end of file.
  ///
  virtual int Eof();

private:
  const unsigned char* bytes_;
  size_t size_;
  size_t offset_;
  CefRefPtr<CefBase> source_;

  IMPLEMENT_REFCOUNTING(CefByteReadHandler);
  IMPLEMENT_LOCKING(CefByteReadHandler);
};


///
// Thread-safe class for accessing zip archive file contents. This class should
// not be used with large archive files because all data will be resident in
// memory at the same time. This implementation supports a restricted set of zip
// archive features:
// (1) Password-protected files are not supported.
// (2) All file names are stored and compared in lower case.
// (3) File ordering from the original zip archive is not maintained. This
//     means that files from the same folder may not be located together in the
//     file content map.
///
class CefZipArchive : public CefBase
{
public:
  ///
  // Class representing a file in the archive. Accessing the file data from
  // multiple threads is safe provided a reference to the File object is kept.
  ///
  class File : public CefBase
  {
  public:
    ///
    // Returns the read-only data contained in the file.
    ///
    virtual const unsigned char* GetData() =0;

    ///
    // Returns the size of the data in the file.
    ///
    virtual size_t GetDataSize() =0;

    ///
    // Returns a CefStreamReader object for streaming the contents of the file.
    ///
    virtual CefRefPtr<CefStreamReader> GetStreamReader() =0;
  };
  typedef std::map<CefString, CefRefPtr<File> > FileMap;

  ///
  // Create a new object.
  ///
  CefZipArchive();
  virtual ~CefZipArchive();

  ///
  // Load the contents of the specified zip archive stream into this object.
  // If |overwriteExisting| is true then any files in this object that also
  // exist in the specified archive will be replaced with the new files.
  // Returns the number of files successfully loaded.
  ///
  size_t Load(CefRefPtr<CefStreamReader> stream, bool overwriteExisting);

  ///
  // Clears the contents of this object.
  ///
  void Clear();

  ///
  // Returns the number of files in the archive.
  ///
  size_t GetFileCount();

  ///
  // Returns true if the specified file exists and has contents.
  ///
  bool HasFile(const CefString& fileName);

  ///
  // Returns the specified file.
  ///
  CefRefPtr<File> GetFile(const CefString& fileName);

  ///
  // Removes the specified file.
  ///
  bool RemoveFile(const CefString& fileName);

  ///
  // Returns the map of all files.
  ///
  size_t GetFiles(FileMap& map);

private:
  FileMap contents_;

  IMPLEMENT_REFCOUNTING(CefZipArchive);
  IMPLEMENT_LOCKING(CefZipArchive);
};

#endif // _CEF_WRAPPER_H
