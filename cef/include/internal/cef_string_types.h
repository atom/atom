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

#ifndef CEF_INCLUDE_INTERNAL_CEF_STRING_TYPES_H_
#define CEF_INCLUDE_INTERNAL_CEF_STRING_TYPES_H_
#pragma once

// CEF provides functions for converting between UTF-8, -16 and -32 strings.
// CEF string types are safe for reading from multiple threads but not for
// modification. It is the user's responsibility to provide synchronization if
// modifying CEF strings from multiple threads.

#ifdef __cplusplus
extern "C" {
#endif

#include "include/internal/cef_build.h"
#include "include/internal/cef_export.h"
#include <stddef.h>

// CEF character type definitions. wchar_t is 2 bytes on Windows and 4 bytes on
// most other platforms.

#if defined(OS_WIN)
typedef wchar_t char16;
#else  // !OS_WIN
typedef unsigned short char16;  // NOLINT (runtime/int)
#ifndef WCHAR_T_IS_UTF32
#define WCHAR_T_IS_UTF32
#endif  // WCHAR_T_IS_UTF32
#endif  // !OS_WIN


// CEF string type definitions. Whomever allocates |str| is responsible for
// providing an appropriate |dtor| implementation that will free the string in
// the same memory space. When reusing an existing string structure make sure
// to call |dtor| for the old value before assigning new |str| and |dtor|
// values. Static strings will have a NULL |dtor| value. Using the below
// functions if you want this managed for you.

typedef struct _cef_string_wide_t {
  wchar_t* str;
  size_t length;
  void (*dtor)(wchar_t* str);
} cef_string_wide_t;

typedef struct _cef_string_utf8_t {
  char* str;
  size_t length;
  void (*dtor)(char* str);
} cef_string_utf8_t;

typedef struct _cef_string_utf16_t {
  char16* str;
  size_t length;
  void (*dtor)(char16* str);
} cef_string_utf16_t;


///
// These functions set string values. If |copy| is true (1) the value will be
// copied instead of referenced. It is up to the user to properly manage
// the lifespan of references.
///

CEF_EXPORT int cef_string_wide_set(const wchar_t* src, size_t src_len,
                                   cef_string_wide_t* output, int copy);
CEF_EXPORT int cef_string_utf8_set(const char* src, size_t src_len,
                                   cef_string_utf8_t* output, int copy);
CEF_EXPORT int cef_string_utf16_set(const char16* src, size_t src_len,
                                    cef_string_utf16_t* output, int copy);


///
// Convenience macros for copying values.
///

#define cef_string_wide_copy(src, src_len, output)  \
    cef_string_wide_set(src, src_len, output, true)
#define cef_string_utf8_copy(src, src_len, output)  \
    cef_string_utf8_set(src, src_len, output, true)
#define cef_string_utf16_copy(src, src_len, output)  \
    cef_string_utf16_set(src, src_len, output, true)


///
// These functions clear string values. The structure itself is not freed.
///

CEF_EXPORT void cef_string_wide_clear(cef_string_wide_t* str);
CEF_EXPORT void cef_string_utf8_clear(cef_string_utf8_t* str);
CEF_EXPORT void cef_string_utf16_clear(cef_string_utf16_t* str);


///
// These functions compare two string values with the same results as strcmp().
///

CEF_EXPORT int cef_string_wide_cmp(const cef_string_wide_t* str1,
                                   const cef_string_wide_t* str2);
CEF_EXPORT int cef_string_utf8_cmp(const cef_string_utf8_t* str1,
                                   const cef_string_utf8_t* str2);
CEF_EXPORT int cef_string_utf16_cmp(const cef_string_utf16_t* str1,
                                    const cef_string_utf16_t* str2);


///
// These functions convert between UTF-8, -16, and -32 strings. They are
// potentially slow so unnecessary conversions should be avoided. The best
// possible result will always be written to |output| with the boolean return
// value indicating whether the conversion is 100% valid.
///

CEF_EXPORT int cef_string_wide_to_utf8(const wchar_t* src, size_t src_len,
                                       cef_string_utf8_t* output);
CEF_EXPORT int cef_string_utf8_to_wide(const char* src, size_t src_len,
                                       cef_string_wide_t* output);

CEF_EXPORT int cef_string_wide_to_utf16(const wchar_t* src, size_t src_len,
                                        cef_string_utf16_t* output);
CEF_EXPORT int cef_string_utf16_to_wide(const char16* src, size_t src_len,
                                        cef_string_wide_t* output);

CEF_EXPORT int cef_string_utf8_to_utf16(const char* src, size_t src_len,
                                        cef_string_utf16_t* output);
CEF_EXPORT int cef_string_utf16_to_utf8(const char16* src, size_t src_len,
                                        cef_string_utf8_t* output);


///
// These functions convert an ASCII string, typically a hardcoded constant, to a
// Wide/UTF16 string. Use instead of the UTF8 conversion routines if you know
// the string is ASCII.
///

CEF_EXPORT int cef_string_ascii_to_wide(const char* src, size_t src_len,
                                        cef_string_wide_t* output);
CEF_EXPORT int cef_string_ascii_to_utf16(const char* src, size_t src_len,
                                         cef_string_utf16_t* output);



///
// It is sometimes necessary for the system to allocate string structures with
// the expectation that the user will free them. The userfree types act as a
// hint that the user is responsible for freeing the structure.
///

typedef cef_string_wide_t* cef_string_userfree_wide_t;
typedef cef_string_utf8_t* cef_string_userfree_utf8_t;
typedef cef_string_utf16_t* cef_string_userfree_utf16_t;


///
// These functions allocate a new string structure. They must be freed by
// calling the associated free function.
///

CEF_EXPORT cef_string_userfree_wide_t cef_string_userfree_wide_alloc();
CEF_EXPORT cef_string_userfree_utf8_t cef_string_userfree_utf8_alloc();
CEF_EXPORT cef_string_userfree_utf16_t cef_string_userfree_utf16_alloc();


///
// These functions free the string structure allocated by the associated
// alloc function. Any string contents will first be cleared.
///

CEF_EXPORT void cef_string_userfree_wide_free(cef_string_userfree_wide_t str);
CEF_EXPORT void cef_string_userfree_utf8_free(cef_string_userfree_utf8_t str);
CEF_EXPORT void cef_string_userfree_utf16_free(cef_string_userfree_utf16_t str);


#ifdef __cplusplus
}
#endif

#endif  // CEF_INCLUDE_INTERNAL_CEF_STRING_TYPES_H_
