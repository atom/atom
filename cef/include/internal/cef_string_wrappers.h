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

#ifndef CEF_INCLUDE_INTERNAL_CEF_STRING_WRAPPERS_H_
#define CEF_INCLUDE_INTERNAL_CEF_STRING_WRAPPERS_H_
#pragma once

#include <memory.h>
#include <string>
#include "include/internal/cef_string_types.h"

#ifdef BUILDING_CEF_SHARED
#include "base/string16.h"
#endif


///
// Traits implementation for wide character strings.
///
struct CefStringTraitsWide {
  typedef wchar_t char_type;
  typedef cef_string_wide_t struct_type;
  typedef cef_string_userfree_wide_t userfree_struct_type;

  static inline void clear(struct_type *s) { cef_string_wide_clear(s); }
  static inline int set(const char_type* src, size_t src_size,
                        struct_type* output, int copy) {
    return cef_string_wide_set(src, src_size, output, copy);
  }
  static inline int compare(const struct_type* s1, const struct_type* s2) {
    return cef_string_wide_cmp(s1, s2);
  }
  static inline userfree_struct_type userfree_alloc() {
    return cef_string_userfree_wide_alloc();
  }
  static inline void userfree_free(userfree_struct_type ufs) {
    return cef_string_userfree_wide_free(ufs);
  }

  // Conversion methods.
  static inline bool from_ascii(const char* str, size_t len, struct_type *s) {
    return cef_string_ascii_to_wide(str, len, s) ? true : false;
  }
  static inline std::string to_string(const struct_type *s) {
    cef_string_utf8_t cstr;
    memset(&cstr, 0, sizeof(cstr));
    cef_string_wide_to_utf8(s->str, s->length, &cstr);
    std::string str;
    if (cstr.length > 0)
      str = std::string(cstr.str, cstr.length);
    cef_string_utf8_clear(&cstr);
    return str;
  }
  static inline bool from_string(const std::string& str, struct_type *s) {
    return cef_string_utf8_to_wide(str.c_str(), str.length(), s) ? true : false;
  }
  static inline std::wstring to_wstring(const struct_type *s) {
    return std::wstring(s->str, s->length);
  }
  static inline bool from_wstring(const std::wstring& str, struct_type *s) {
    return cef_string_wide_set(str.c_str(), str.length(), s, true) ?
        true : false;
  }
#if defined(BUILDING_CEF_SHARED)
#if defined(WCHAR_T_IS_UTF32)
  static inline string16 to_string16(const struct_type *s) {
    cef_string_utf16_t cstr;
    memset(&cstr, 0, sizeof(cstr));
    cef_string_wide_to_utf16(s->str, s->length, &cstr);
    string16 str;
    if (cstr.length > 0)
      str = string16(cstr.str, cstr.length);
    cef_string_utf16_clear(&cstr);
    return str;
  }
  static inline bool from_string16(const string16& str, struct_type *s) {
    return cef_string_utf16_to_wide(str.c_str(), str.length(), s) ?
        true : false;
  }
#else  // WCHAR_T_IS_UTF32
  static inline string16 to_string16(const struct_type *s) {
    return string16(s->str, s->length);
  }
  static inline bool from_string16(const string16& str, struct_type *s) {
    return cef_string_wide_set(str.c_str(), str.length(), s, true) ?
        true : false;
  }
#endif  // WCHAR_T_IS_UTF32
#endif  // BUILDING_CEF_SHARED
};

///
// Traits implementation for utf8 character strings.
///
struct CefStringTraitsUTF8 {
  typedef char char_type;
  typedef cef_string_utf8_t struct_type;
  typedef cef_string_userfree_utf8_t userfree_struct_type;

  static inline void clear(struct_type *s) { cef_string_utf8_clear(s); }
  static inline int set(const char_type* src, size_t src_size,
                        struct_type* output, int copy) {
    return cef_string_utf8_set(src, src_size, output, copy);
  }
  static inline int compare(const struct_type* s1, const struct_type* s2) {
    return cef_string_utf8_cmp(s1, s2);
  }
  static inline userfree_struct_type userfree_alloc() {
    return cef_string_userfree_utf8_alloc();
  }
  static inline void userfree_free(userfree_struct_type ufs) {
    return cef_string_userfree_utf8_free(ufs);
  }

  // Conversion methods.
  static inline bool from_ascii(const char* str, size_t len, struct_type* s) {
    return cef_string_utf8_copy(str, len, s) ? true : false;
  }
  static inline std::string to_string(const struct_type* s) {
    return std::string(s->str, s->length);
  }
  static inline bool from_string(const std::string& str, struct_type* s) {
    return cef_string_utf8_copy(str.c_str(), str.length(), s) ? true : false;
  }
  static inline std::wstring to_wstring(const struct_type* s) {
    cef_string_wide_t cstr;
    memset(&cstr, 0, sizeof(cstr));
    cef_string_utf8_to_wide(s->str, s->length, &cstr);
    std::wstring str;
    if (cstr.length > 0)
      str = std::wstring(cstr.str, cstr.length);
    cef_string_wide_clear(&cstr);
    return str;
  }
  static inline bool from_wstring(const std::wstring& str, struct_type* s) {
    return cef_string_wide_to_utf8(str.c_str(), str.length(), s) ? true : false;
  }
#if defined(BUILDING_CEF_SHARED)
  static inline string16 to_string16(const struct_type* s) {
    cef_string_utf16_t cstr;
    memset(&cstr, 0, sizeof(cstr));
    cef_string_utf8_to_utf16(s->str, s->length, &cstr);
    string16 str;
    if (cstr.length > 0)
      str = string16(cstr.str, cstr.length);
    cef_string_utf16_clear(&cstr);
    return str;
  }
  static inline bool from_string16(const string16& str, struct_type* s) {
    return cef_string_utf16_to_utf8(str.c_str(), str.length(), s) ?
        true : false;
  }
#endif  // BUILDING_CEF_SHARED
};

///
// Traits implementation for utf16 character strings.
///
struct CefStringTraitsUTF16 {
  typedef char16 char_type;
  typedef cef_string_utf16_t struct_type;
  typedef cef_string_userfree_utf16_t userfree_struct_type;

  static inline void clear(struct_type *s) { cef_string_utf16_clear(s); }
  static inline int set(const char_type* src, size_t src_size,
                        struct_type* output, int copy) {
    return cef_string_utf16_set(src, src_size, output, copy);
  }
  static inline int compare(const struct_type* s1, const struct_type* s2) {
    return cef_string_utf16_cmp(s1, s2);
  }
  static inline userfree_struct_type userfree_alloc() {
    return cef_string_userfree_utf16_alloc();
  }
  static inline void userfree_free(userfree_struct_type ufs) {
    return cef_string_userfree_utf16_free(ufs);
  }

  // Conversion methods.
  static inline bool from_ascii(const char* str, size_t len, struct_type* s) {
    return cef_string_ascii_to_utf16(str, len, s) ? true : false;
  }
  static inline std::string to_string(const struct_type* s) {
    cef_string_utf8_t cstr;
    memset(&cstr, 0, sizeof(cstr));
    cef_string_utf16_to_utf8(s->str, s->length, &cstr);
    std::string str;
    if (cstr.length > 0)
      str = std::string(cstr.str, cstr.length);
    cef_string_utf8_clear(&cstr);
    return str;
  }
  static inline bool from_string(const std::string& str, struct_type* s) {
    return cef_string_utf8_to_utf16(str.c_str(), str.length(), s) ?
        true : false;
  }
#if defined(WCHAR_T_IS_UTF32)
  static inline std::wstring to_wstring(const struct_type* s) {
    cef_string_wide_t cstr;
    memset(&cstr, 0, sizeof(cstr));
    cef_string_utf16_to_wide(s->str, s->length, &cstr);
    std::wstring str;
    if (cstr.length > 0)
      str = std::wstring(cstr.str, cstr.length);
    cef_string_wide_clear(&cstr);
    return str;
  }
  static inline bool from_wstring(const std::wstring& str, struct_type* s) {
    return cef_string_wide_to_utf16(str.c_str(), str.length(), s) ?
        true : false;
  }
#else  // WCHAR_T_IS_UTF32
  static inline std::wstring to_wstring(const struct_type* s) {
    return std::wstring(s->str, s->length);
  }
  static inline bool from_wstring(const std::wstring& str, struct_type* s) {
    return cef_string_utf16_set(str.c_str(), str.length(), s, true) ?
        true : false;
  }
#endif  // WCHAR_T_IS_UTF32
#if defined(BUILDING_CEF_SHARED)
  static inline string16 to_string16(const struct_type* s) {
    return string16(s->str, s->length);
  }
  static inline bool from_string16(const string16& str, struct_type* s) {
    return cef_string_utf16_set(str.c_str(), str.length(), s, true) ?
        true : false;
  }
#endif  // BUILDING_CEF_SHARED
};

///
// CEF string classes can convert between all supported string types. For
// example, the CefStringWide class uses wchar_t as the underlying character
// type and provides two approaches for converting data to/from a UTF8 string
// (std::string).
// <p>
// 1. Implicit conversion using the assignment operator overload.
// <pre>
//   CefStringWide aCefString;
//   std::string aUTF8String;
//   aCefString = aUTF8String; // Assign std::string to CefStringWide
//   aUTF8String = aCefString; // Assign CefStringWide to std::string
// </pre>
// 2. Explicit conversion using the FromString/ToString methods.
// <pre>
//   CefStringWide aCefString;
//   std::string aUTF8String;
//   aCefString.FromString(aUTF8String); // Assign std::string to CefStringWide
//   aUTF8String = aCefString.ToString(); // Assign CefStringWide to std::string
// </pre>
// Conversion will only occur if the assigned value is a different string type.
// Assigning a std::string to a CefStringUTF8, for example, will copy the data
// without performing a conversion.
// </p>
// CEF string classes are safe for reading from multiple threads but not for
// modification. It is the user's responsibility to provide synchronization if
// modifying CEF strings from multiple threads.
///
template <class traits>
class CefStringBase {
 public:
  typedef typename traits::char_type char_type;
  typedef typename traits::struct_type struct_type;
  typedef typename traits::userfree_struct_type userfree_struct_type;

  ///
  // Default constructor.
  ///
  CefStringBase() : string_(NULL), owner_(false) {}

  ///
  // Create a new string from an existing string. Data will always be copied.
  ///
  CefStringBase(const CefStringBase& str)
    : string_(NULL), owner_(false) {
    FromString(str.c_str(), str.length(), true);
  }

  ///
  // Create a new string from an existing std::string. Data will be always
  // copied. Translation will occur if necessary based on the underlying string
  // type.
  ///
  CefStringBase(const std::string& src)  // NOLINT(runtime/explicit)
    : string_(NULL), owner_(false) {
    FromString(src);
  }
  CefStringBase(const char* src)  // NOLINT(runtime/explicit)
    : string_(NULL), owner_(false) {
    if (src)
      FromString(std::string(src));
  }

  ///
  // Create a new string from an existing std::wstring. Data will be always
  // copied. Translation will occur if necessary based on the underlying string
  // type.
  ///
  CefStringBase(const std::wstring& src)  // NOLINT(runtime/explicit)
    : string_(NULL), owner_(false) {
    FromWString(src);
  }
  CefStringBase(const wchar_t* src)  // NOLINT(runtime/explicit)
    : string_(NULL), owner_(false) {
    if (src)
      FromWString(std::wstring(src));
  }

#if (defined(BUILDING_CEF_SHARED) && defined(WCHAR_T_IS_UTF32))
  ///
  // Create a new string from an existing string16. Data will be always
  // copied. Translation will occur if necessary based on the underlying string
  // type.
  ///
  CefStringBase(const string16& src)  // NOLINT(runtime/explicit)
    : string_(NULL), owner_(false) {
    FromString16(src);
  }
  CefStringBase(const char16* src)  // NOLINT(runtime/explicit)
    : string_(NULL), owner_(false) {
    if (src)
      FromString16(string16(src));
  }
#endif  // BUILDING_CEF_SHARED && WCHAR_T_IS_UTF32

  ///
  // Create a new string from an existing character array. If |copy| is true
  // this class will copy the data. Otherwise, this class will reference the
  // existing data. Referenced data must exist for the lifetime of this class
  // and will not be freed by this class.
  ///
  CefStringBase(const char_type* src, size_t src_len, bool copy)
    : string_(NULL), owner_(false) {
    if (src && src_len > 0)
      FromString(src, src_len, copy);
  }

  ///
  // Create a new string referencing an existing string structure without taking
  // ownership. Referenced structures must exist for the lifetime of this class
  // and will not be freed by this class.
  ///
  CefStringBase(const struct_type* src)  // NOLINT(runtime/explicit)
    : string_(NULL), owner_(false) {
    if (!src)
      return;
    // Reference the existing structure without taking ownership.
    Attach(const_cast<struct_type*>(src), false);
  }

  virtual ~CefStringBase() { ClearAndFree(); }


  // The following methods are named for compatibility with the standard library
  // string template types.

  ///
  // Return a read-only pointer to the string data.
  ///
  const char_type* c_str() const { return (string_ ? string_->str : NULL); }

  ///
  // Return the length of the string data.
  ///
  size_t length() const { return (string_ ? string_->length : 0); }

  ///
  // Return the length of the string data.
  ///
  inline size_t size() const { return length(); }

  ///
  // Returns true if the string is empty.
  ///
  bool empty() const { return (string_ == NULL || string_->length == 0); }

  ///
  // Compare this string to the specified string.
  ///
  int compare(const CefStringBase& str) const {
    if (empty() && str.empty())
      return 0;
    if (empty())
      return -1;
    if (str.empty())
      return 1;
    return traits::compare(string_, str.GetStruct());
  }

  ///
  // Clear the string data.
  ///
  void clear() {
    if (string_)
      traits::clear(string_);
  }

  ///
  // Swap this string's contents with the specified string.
  ///
  void swap(CefStringBase& str) {
    struct_type* tmp_string = string_;
    bool tmp_owner = owner_;
    string_ = str.string_;
    owner_ = str.owner_;
    str.string_ = tmp_string;
    str.owner_ = tmp_owner;
  }


  // The following methods are unique to CEF string template types.

  ///
  // Returns true if this class owns the underlying string structure.
  ///
  bool IsOwner() const { return owner_; }

  ///
  // Returns a read-only pointer to the underlying string structure. May return
  // NULL if no structure is currently allocated.
  ///
  const struct_type* GetStruct() const { return string_; }

  ///
  // Returns a writable pointer to the underlying string structure. Will never
  // return NULL.
  ///
  struct_type* GetWritableStruct() {
    AllocIfNeeded();
    return string_;
  }

  ///
  // Clear the state of this class. The underlying string structure and data
  // will be freed if this class owns the structure.
  ///
  void ClearAndFree() {
    if (!string_)
      return;
    if (owner_) {
      clear();
      delete string_;
    }
    string_ = NULL;
    owner_ = false;
  }

  ///
  // Attach to the specified string structure. If |owner| is true this class
  // will take ownership of the structure.
  ///
  void Attach(struct_type* str, bool owner) {
    // Free the previous structure and data, if any.
    ClearAndFree();

    string_ = str;
    owner_ = owner;
  }

  ///
  // Take ownership of the specified userfree structure's string data. The
  // userfree structure itself will be freed. Only use this method with userfree
  // structures.
  ///
  void AttachToUserFree(userfree_struct_type str) {
    // Free the previous structure and data, if any.
    ClearAndFree();

    if (!str)
      return;

    AllocIfNeeded();
    owner_ = true;
    memcpy(string_, str, sizeof(struct_type));

    // Free the |str| structure but not the data.
    memset(str, 0, sizeof(struct_type));
    traits::userfree_free(str);
  }

  ///
  // Detach from the underlying string structure. To avoid memory leaks only use
  // this method if you already hold a pointer to the underlying string
  // structure.
  ///
  void Detach() {
    string_ = NULL;
    owner_ = false;
  }

  ///
  // Create a userfree structure and give it ownership of this class' string
  // data. This class will be disassociated from the data. May return NULL if
  // this string class currently contains no data.
  ///
  userfree_struct_type DetachToUserFree() {
    if (empty())
      return NULL;

    userfree_struct_type str = traits::userfree_alloc();
    memcpy(str, string_, sizeof(struct_type));

    // Free this class' structure but not the data.
    memset(string_, 0, sizeof(struct_type));
    ClearAndFree();

    return str;
  }

  ///
  // Set this string's data to the specified character array. If |copy| is true
  // this class will copy the data. Otherwise, this class will reference the
  // existing data. Referenced data must exist for the lifetime of this class
  // and will not be freed by this class.
  ///
  bool FromString(const char_type* src, size_t src_len, bool copy) {
    if (src == NULL || src_len == 0) {
      clear();
      return true;
    }
    AllocIfNeeded();
    return traits::set(src, src_len, string_, copy) ? true : false;
  }

  ///
  // Set this string's data from an existing ASCII string. Data will be always
  // copied. Translation will occur if necessary based on the underlying string
  // type.
  ///
  bool FromASCII(const char* str) {
    size_t len = str ? strlen(str) : 0;
    if (len == 0) {
      clear();
      return true;
    }
    AllocIfNeeded();
    return traits::from_ascii(str, len, string_);
  }

  ///
  // Return this string's data as a std::string. Translation will occur if
  // necessary based on the underlying string type.
  ///
  std::string ToString() const {
    if (empty())
      return std::string();
    return traits::to_string(string_);
  }

  ///
  // Set this string's data from an existing std::string. Data will be always
  // copied. Translation will occur if necessary based on the underlying string
  // type.
  ///
  bool FromString(const std::string& str) {
    if (str.empty()) {
      clear();
      return true;
    }
    AllocIfNeeded();
    return traits::from_string(str, string_);
  }

  ///
  // Return this string's data as a std::wstring. Translation will occur if
  // necessary based on the underlying string type.
  ///
  std::wstring ToWString() const {
    if (empty())
      return std::wstring();
    return traits::to_wstring(string_);
  }

  ///
  // Set this string's data from an existing std::wstring. Data will be always
  // copied. Translation will occur if necessary based on the underlying string
  // type.
  ///
  bool FromWString(const std::wstring& str) {
    if (str.empty()) {
      clear();
      return true;
    }
    AllocIfNeeded();
    return traits::from_wstring(str, string_);
  }
#if defined(BUILDING_CEF_SHARED)
  ///
  // Return this string's data as a string16. Translation will occur if
  // necessary based on the underlying string type.
  ///
  string16 ToString16() const {
    if (empty())
      return string16();
    return traits::to_string16(string_);
  }

  ///
  // Set this string's data from an existing string16. Data will be always
  // copied. Translation will occur if necessary based on the underlying string
  // type.
  ///
  bool FromString16(const string16& str) {
    if (str.empty()) {
      clear();
      return true;
    }
    AllocIfNeeded();
    return traits::from_string16(str, string_);
  }
#endif  // BUILDING_CEF_SHARED

  ///
  // Comparison operator overloads.
  ///
  bool operator<(const CefStringBase& str) const {
    return (compare(str) < 0);
  }
  bool operator<=(const CefStringBase& str) const {
    return (compare(str) <= 0);
  }
  bool operator>(const CefStringBase& str) const {
    return (compare(str) > 0);
  }
  bool operator>=(const CefStringBase& str) const {
    return (compare(str) >= 0);
  }
  bool operator==(const CefStringBase& str) const {
    return (compare(str) == 0);
  }
  bool operator!=(const CefStringBase& str) const {
    return (compare(str) != 0);
  }

  ///
  // Assignment operator overloads.
  ///
  CefStringBase& operator=(const CefStringBase& str) {
    FromString(str.c_str(), str.length(), true);
    return *this;
  }
  operator std::string() const {
    return ToString();
  }
  CefStringBase& operator=(const std::string& str) {
    FromString(str);
    return *this;
  }
  CefStringBase& operator=(const char* str) {
    FromString(std::string(str));
    return *this;
  }
  operator std::wstring() const {
    return ToWString();
  }
  CefStringBase& operator=(const std::wstring& str) {
    FromWString(str);
    return *this;
  }
  CefStringBase& operator=(const wchar_t* str) {
    FromWString(std::wstring(str));
    return *this;
  }
#if (defined(BUILDING_CEF_SHARED) && defined(WCHAR_T_IS_UTF32))
  operator string16() const {
    return ToString16();
  }
  CefStringBase& operator=(const string16& str) {
    FromString16(str);
    return *this;
  }
  CefStringBase& operator=(const char16* str) {
    FromString16(string16(str));
    return *this;
  }
#endif  // BUILDING_CEF_SHARED && WCHAR_T_IS_UTF32

 private:
  // Allocate the string structure if it doesn't already exist.
  void AllocIfNeeded() {
    if (string_ == NULL) {
      string_ = new struct_type;
      memset(string_, 0, sizeof(struct_type));
      owner_ = true;
    }
  }

  struct_type* string_;
  bool owner_;
};


typedef CefStringBase<CefStringTraitsWide> CefStringWide;
typedef CefStringBase<CefStringTraitsUTF8> CefStringUTF8;
typedef CefStringBase<CefStringTraitsUTF16> CefStringUTF16;

#endif  // CEF_INCLUDE_INTERNAL_CEF_STRING_WRAPPERS_H_
