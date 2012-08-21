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


#ifndef CEF_INCLUDE_CAPI_CEF_BASE_CAPI_H_
#define CEF_INCLUDE_CAPI_CEF_BASE_CAPI_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "include/internal/cef_export.h"
#include "include/internal/cef_string.h"
#include "include/internal/cef_string_list.h"
#include "include/internal/cef_string_map.h"
#include "include/internal/cef_string_multimap.h"
#include "include/internal/cef_types.h"

///
// Structure defining the reference count implementation functions. All
// framework structures must include the cef_base_t structure first.
///
typedef struct _cef_base_t {
  ///
  // Size of the data structure.
  ///
  size_t size;

  ///
  // Increment the reference count.
  ///
  int (CEF_CALLBACK *add_ref)(struct _cef_base_t* self);

  ///
  // Decrement the reference count.  Delete this object when no references
  // remain.
  ///
  int (CEF_CALLBACK *release)(struct _cef_base_t* self);

  ///
  // Returns the current number of references.
  ///
  int (CEF_CALLBACK *get_refct)(struct _cef_base_t* self);
} cef_base_t;


// Check that the structure |s|, which is defined with a cef_base_t member named
// |base|, is large enough to contain the specified member |f|.
#define CEF_MEMBER_EXISTS(s, f)   \
  ((intptr_t)&((s)->f) - (intptr_t)(s) + sizeof((s)->f) <= (s)->base.size)

#define CEF_MEMBER_MISSING(s, f)  (!CEF_MEMBER_EXISTS(s, f) || !((s)->f))


#ifdef __cplusplus
}
#endif

#endif  // CEF_INCLUDE_CAPI_CEF_BASE_CAPI_H_
