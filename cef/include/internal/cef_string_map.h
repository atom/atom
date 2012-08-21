// Copyright (c) 2009 Marshall A. Greenblatt. All rights reserved.
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

#ifndef CEF_INCLUDE_INTERNAL_CEF_STRING_MAP_H_
#define CEF_INCLUDE_INTERNAL_CEF_STRING_MAP_H_
#pragma once

#include "include/internal/cef_export.h"
#include "include/internal/cef_string.h"

#ifdef __cplusplus
extern "C" {
#endif

///
// CEF string maps are a set of key/value string pairs.
///
typedef void* cef_string_map_t;

///
// Allocate a new string map.
///
CEF_EXPORT cef_string_map_t cef_string_map_alloc();

///
// Return the number of elements in the string map.
///
CEF_EXPORT int cef_string_map_size(cef_string_map_t map);

///
// Return the value assigned to the specified key.
///
CEF_EXPORT int cef_string_map_find(cef_string_map_t map,
                                   const cef_string_t* key,
                                   cef_string_t* value);

///
// Return the key at the specified zero-based string map index.
///
CEF_EXPORT int cef_string_map_key(cef_string_map_t map, int index,
                                  cef_string_t* key);

///
// Return the value at the specified zero-based string map index.
///
CEF_EXPORT int cef_string_map_value(cef_string_map_t map, int index,
                                    cef_string_t* value);

///
// Append a new key/value pair at the end of the string map.
///
CEF_EXPORT int cef_string_map_append(cef_string_map_t map,
                                     const cef_string_t* key,
                                     const cef_string_t* value);

///
// Clear the string map.
///
CEF_EXPORT void cef_string_map_clear(cef_string_map_t map);

///
// Free the string map.
///
CEF_EXPORT void cef_string_map_free(cef_string_map_t map);


#ifdef __cplusplus
}
#endif

#endif  // CEF_INCLUDE_INTERNAL_CEF_STRING_MAP_H_
