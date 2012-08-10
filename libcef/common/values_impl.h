// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_VALUES_IMPL_H_
#define CEF_LIBCEF_COMMON_VALUES_IMPL_H_
#pragma once

#include <vector>

#include "include/cef_values.h"
#include "libcef/common/value_base.h"

#include "base/values.h"
#include "base/threading/platform_thread.h"


// CefBinaryValue implementation
class CefBinaryValueImpl
    : public CefValueBase<CefBinaryValue, base::BinaryValue> {
 public:
  // Get or create a reference value.
  static CefRefPtr<CefBinaryValue> GetOrCreateRef(
      base::BinaryValue* value,
      void* parent_value,
      CefValueController* controller);

  // Return a copy of the value.
  base::BinaryValue* CopyValue();

  // If a reference return a copy of the value otherwise detach the value to the
  // specified |new_controller|.
  base::BinaryValue* CopyOrDetachValue(CefValueController* new_controller);

  // CefBinaryValue methods.
  virtual bool IsValid() OVERRIDE;
  virtual bool IsOwned() OVERRIDE;
  virtual CefRefPtr<CefBinaryValue> Copy() OVERRIDE;
  virtual size_t GetSize() OVERRIDE;
  virtual size_t GetData(void* buffer,
                         size_t buffer_size,
                         size_t data_offset) OVERRIDE;

 private:
  // See the CefValueBase constructor for usage. Binary values are always
  // read-only.
  CefBinaryValueImpl(base::BinaryValue* value,
                     void* parent_value,
                     ValueMode value_mode,
                     CefValueController* controller);
  // If |copy| is false this object will take ownership of the specified |data|
  // buffer instead of copying it.
  CefBinaryValueImpl(char* data,
                     size_t data_size,
                     bool copy);

  // For the Create() method.
  friend class CefBinaryValue;

  DISALLOW_COPY_AND_ASSIGN(CefBinaryValueImpl);
};


// CefDictionaryValue implementation
class CefDictionaryValueImpl
    : public CefValueBase<CefDictionaryValue, base::DictionaryValue> {
 public:
  // Get or create a reference value.
  static CefRefPtr<CefDictionaryValue> GetOrCreateRef(
      base::DictionaryValue* value,
      void* parent_value,
      bool read_only,
      CefValueController* controller);

  // Return a copy of the value.
  base::DictionaryValue* CopyValue();

  // If a reference return a copy of the value otherwise detach the value to the
  // specified |new_controller|.
  base::DictionaryValue* CopyOrDetachValue(CefValueController* new_controller);

  // CefDictionaryValue methods.
  virtual bool IsValid() OVERRIDE;
  virtual bool IsOwned() OVERRIDE;
  virtual bool IsReadOnly() OVERRIDE;
  virtual CefRefPtr<CefDictionaryValue> Copy(
      bool exclude_empty_children) OVERRIDE;
  virtual size_t GetSize() OVERRIDE;
  virtual bool Clear() OVERRIDE;
  virtual bool HasKey(const CefString& key) OVERRIDE;
  virtual bool GetKeys(KeyList& keys) OVERRIDE;
  virtual bool Remove(const CefString& key) OVERRIDE;
  virtual CefValueType GetType(const CefString& key) OVERRIDE;
  virtual bool GetBool(const CefString& key) OVERRIDE;
  virtual int GetInt(const CefString& key) OVERRIDE;
  virtual double GetDouble(const CefString& key) OVERRIDE;
  virtual CefString GetString(const CefString& key) OVERRIDE;
  virtual CefRefPtr<CefBinaryValue> GetBinary(const CefString& key) OVERRIDE;
  virtual CefRefPtr<CefDictionaryValue> GetDictionary(
      const CefString& key) OVERRIDE;
  virtual CefRefPtr<CefListValue> GetList(const CefString& key) OVERRIDE;
  virtual bool SetNull(const CefString& key) OVERRIDE;
  virtual bool SetBool(const CefString& key, bool value) OVERRIDE;
  virtual bool SetInt(const CefString& key, int value) OVERRIDE;
  virtual bool SetDouble(const CefString& key, double value) OVERRIDE;
  virtual bool SetString(const CefString& key,
                         const CefString& value) OVERRIDE;
  virtual bool SetBinary(const CefString& key,
      CefRefPtr<CefBinaryValue> value) OVERRIDE;
  virtual bool SetDictionary(const CefString& key,
      CefRefPtr<CefDictionaryValue> value) OVERRIDE;
  virtual bool SetList(const CefString& key,
      CefRefPtr<CefListValue> value) OVERRIDE;

 private:
  // See the CefValueBase constructor for usage.
  CefDictionaryValueImpl(base::DictionaryValue* value,
                         void* parent_value,
                         ValueMode value_mode,
                         bool read_only,
                         CefValueController* controller);

  bool RemoveInternal(const CefString& key);

  // For the Create() method.
  friend class CefDictionaryValue;

  DISALLOW_COPY_AND_ASSIGN(CefDictionaryValueImpl);
};


// CefListValue implementation
class CefListValueImpl
    : public CefValueBase<CefListValue, base::ListValue> {
 public:
  // Get or create a reference value.
  static CefRefPtr<CefListValue> GetOrCreateRef(
      base::ListValue* value,
      void* parent_value,
      bool read_only,
      CefValueController* controller);

  // Return a copy of the value.
  base::ListValue* CopyValue();

  // If a reference return a copy of the value otherwise detach the value to the
  // specified |new_controller|.
  base::ListValue* CopyOrDetachValue(CefValueController* new_controller);

  /// CefListValue methods.
  virtual bool IsValid() OVERRIDE;
  virtual bool IsOwned() OVERRIDE;
  virtual bool IsReadOnly() OVERRIDE;
  virtual CefRefPtr<CefListValue> Copy() OVERRIDE;
  virtual bool SetSize(size_t size) OVERRIDE;
  virtual size_t GetSize() OVERRIDE;
  virtual bool Clear() OVERRIDE;
  virtual bool Remove(int index) OVERRIDE;
  virtual CefValueType GetType(int index) OVERRIDE;
  virtual bool GetBool(int index) OVERRIDE;
  virtual int GetInt(int index) OVERRIDE;
  virtual double GetDouble(int index) OVERRIDE;
  virtual CefString GetString(int index) OVERRIDE;
  virtual CefRefPtr<CefBinaryValue> GetBinary(int index) OVERRIDE;
  virtual CefRefPtr<CefDictionaryValue> GetDictionary(int index) OVERRIDE;
  virtual CefRefPtr<CefListValue> GetList(int index) OVERRIDE;
  virtual bool SetNull(int index) OVERRIDE;
  virtual bool SetBool(int index, bool value) OVERRIDE;
  virtual bool SetInt(int index, int value) OVERRIDE;
  virtual bool SetDouble(int index, double value) OVERRIDE;
  virtual bool SetString(int index, const CefString& value) OVERRIDE;
  virtual bool SetBinary(int index, CefRefPtr<CefBinaryValue> value) OVERRIDE;
  virtual bool SetDictionary(int index,
                             CefRefPtr<CefDictionaryValue> value) OVERRIDE;
  virtual bool SetList(int index, CefRefPtr<CefListValue> value) OVERRIDE;

 private:
  // See the CefValueBase constructor for usage.
  CefListValueImpl(base::ListValue* value,
                   void* parent_value,
                   ValueMode value_mode,
                   bool read_only,
                   CefValueController* controller);

  bool RemoveInternal(int index);

  // For the Create() method.
  friend class CefListValue;

  DISALLOW_COPY_AND_ASSIGN(CefListValueImpl);
};


#endif  // CEF_LIBCEF_COMMON_VALUES_IMPL_H_
