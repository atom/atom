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

#ifndef CEF_INCLUDE_CEF_STORAGE_H_
#define CEF_INCLUDE_CEF_STORAGE_H_
#pragma once

#include "include/cef_base.h"

class CefStorageVisitor;

typedef cef_storage_type_t CefStorageType;

///
// Visit storage of the specified type. If |origin| is non-empty only data
// matching that origin will be visited. If |key| is non-empty only data
// matching that key will be visited. Otherwise, all data for the storage
// type will be visited. Origin should be of the form scheme://domain. If no
// origin is specified only data currently in memory will be returned. Returns
// false if the storage cannot be accessed.
///
/*--cef(optional_param=origin,optional_param=key)--*/
bool CefVisitStorage(CefStorageType type, const CefString& origin,
                     const CefString& key,
                     CefRefPtr<CefStorageVisitor> visitor);

///
// Sets storage of the specified type, origin, key and value. Returns false if
// storage cannot be accessed. This method must be called on the UI thread.
///
/*--cef()--*/
bool CefSetStorage(CefStorageType type, const CefString& origin,
                   const CefString& key, const CefString& value);

///
// Deletes all storage of the specified type. If |origin| is non-empty only data
// matching that origin will be cleared. If |key| is non-empty only data
// matching that key will be cleared. Otherwise, all data for the storage type
// will be cleared. Returns false if storage cannot be accessed. This method
// must be called on the UI thread.
///
/*--cef(optional_param=origin,optional_param=key)--*/
bool CefDeleteStorage(CefStorageType type, const CefString& origin,
                      const CefString& key);

///
// Sets the directory path that will be used for storing data of the specified
// type. Currently only the ST_LOCALSTORAGE type is supported by this method.
// If |path| is empty data will be stored in memory only. By default the storage
// path is the same as the cache path. Returns false if the storage cannot be
// accessed.
///
/*--cef(optional_param=path)--*/
bool CefSetStoragePath(CefStorageType type, const CefString& path);


///
// Interface to implement for visiting storage. The methods of this class will
// always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefStorageVisitor : public virtual CefBase {
 public:
  ///
  // Method that will be called once for each key/value data pair in storage.
  // |count| is the 0-based index for the current pair. |total| is the total
  // number of pairs. Set |deleteData| to true to delete the pair currently
  // being visited. Return false to stop visiting pairs. This method may never
  // be called if no data is found.
  ///
  /*--cef()--*/
  virtual bool Visit(CefStorageType type, const CefString& origin,
                     const CefString& key, const CefString& value, int count,
                     int total, bool& deleteData) =0;
};

#endif  // CEF_INCLUDE_CEF_STORAGE_H_
