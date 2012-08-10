// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/common/values_impl.h"

#include <algorithm>
#include <vector>


// CefBinaryValueImpl implementation.

CefRefPtr<CefBinaryValue> CefBinaryValue::Create(const void* data,
                                                 size_t data_size) {
  DCHECK(data);
  DCHECK_GT(data_size, (size_t)0);
  if (!data || data_size == 0)
    return NULL;

  return new CefBinaryValueImpl(static_cast<char*>(const_cast<void*>(data)),
      data_size, true);
}

// static
CefRefPtr<CefBinaryValue> CefBinaryValueImpl::GetOrCreateRef(
      base::BinaryValue* value,
      void* parent_value,
      CefValueController* controller) {
  DCHECK(value);
  DCHECK(parent_value);
  DCHECK(controller);

  CefValueController::Object* object = controller->Get(value);
  if (object)
    return static_cast<CefBinaryValueImpl*>(object);

  return new CefBinaryValueImpl(value, parent_value,
      CefBinaryValueImpl::kReference, controller);
}

base::BinaryValue* CefBinaryValueImpl::CopyValue() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);
  return const_value().DeepCopy();
}

base::BinaryValue* CefBinaryValueImpl::CopyOrDetachValue(
    CefValueController* new_controller) {
  base::BinaryValue* new_value;

  if (!will_delete()) {
    // Copy the value.
    new_value = CopyValue();
  } else {
    // Take ownership of the value.
    new_value = Detach(new_controller);
  }

  DCHECK(new_value);
  return new_value;
}

bool CefBinaryValueImpl::IsValid() {
  return !detached();
}

bool CefBinaryValueImpl::IsOwned() {
  return !will_delete();
}

CefRefPtr<CefBinaryValue> CefBinaryValueImpl::Copy() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);
  return new CefBinaryValueImpl(const_value().DeepCopy(), NULL,
      CefBinaryValueImpl::kOwnerWillDelete, NULL);
}

size_t CefBinaryValueImpl::GetSize() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().GetSize();
}

size_t CefBinaryValueImpl::GetData(void* buffer,
                                   size_t buffer_size,
                                   size_t data_offset) {
  DCHECK(buffer);
  DCHECK_GT(buffer_size, (size_t)0);
  if (!buffer || buffer_size == 0)
    return 0;

  CEF_VALUE_VERIFY_RETURN(false, 0);

  size_t size = const_value().GetSize();
  DCHECK_LT(data_offset, size);
  if (data_offset >= size)
    return 0;

  size = std::min(buffer_size, size-data_offset);
  const char* data = const_value().GetBuffer();
  memcpy(buffer, data+data_offset, size);
  return size;
}

CefBinaryValueImpl::CefBinaryValueImpl(base::BinaryValue* value,
                                       void* parent_value,
                                       ValueMode value_mode,
                                       CefValueController* controller)
  : CefValueBase<CefBinaryValue, base::BinaryValue>(
        value, parent_value, value_mode, true, controller) {
}

CefBinaryValueImpl::CefBinaryValueImpl(char* data,
                                       size_t data_size,
                                       bool copy)
  : CefValueBase<CefBinaryValue, base::BinaryValue>(
        copy ? base::BinaryValue::CreateWithCopiedBuffer(data, data_size) :
               base::BinaryValue::Create(data, data_size),
        NULL, kOwnerWillDelete, true, NULL) {
}


// CefDictionaryValueImpl implementation.

// static
CefRefPtr<CefDictionaryValue> CefDictionaryValue::Create() {
  return new CefDictionaryValueImpl(new base::DictionaryValue(),
      NULL, CefDictionaryValueImpl::kOwnerWillDelete, false, NULL);
}

// static
CefRefPtr<CefDictionaryValue> CefDictionaryValueImpl::GetOrCreateRef(
    base::DictionaryValue* value,
    void* parent_value,
    bool read_only,
    CefValueController* controller) {
  CefValueController::Object* object = controller->Get(value);
  if (object)
    return static_cast<CefDictionaryValueImpl*>(object);

  return new CefDictionaryValueImpl(value, parent_value,
      CefDictionaryValueImpl::kReference, read_only, controller);
}

base::DictionaryValue* CefDictionaryValueImpl::CopyValue() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);
  return const_value().DeepCopy();
}

base::DictionaryValue* CefDictionaryValueImpl::CopyOrDetachValue(
    CefValueController* new_controller) {
  base::DictionaryValue* new_value;

  if (!will_delete()) {
    // Copy the value.
    new_value = CopyValue();
  } else {
    // Take ownership of the value.
    new_value = Detach(new_controller);
  }

  DCHECK(new_value);
  return new_value;
}

bool CefDictionaryValueImpl::IsValid() {
  return !detached();
}

bool CefDictionaryValueImpl::IsOwned() {
  return !will_delete();
}

bool CefDictionaryValueImpl::IsReadOnly() {
  return read_only();
}

CefRefPtr<CefDictionaryValue> CefDictionaryValueImpl::Copy(
    bool exclude_empty_children) {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  base::DictionaryValue* value;
  if (exclude_empty_children) {
    value = const_cast<base::DictionaryValue&>(
        const_value()).DeepCopyWithoutEmptyChildren();
  } else {
    value = const_value().DeepCopy();
  }

  return new CefDictionaryValueImpl(value, NULL,
      CefDictionaryValueImpl::kOwnerWillDelete, false, NULL);
}

size_t CefDictionaryValueImpl::GetSize() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().size();
}

bool CefDictionaryValueImpl::Clear() {
  CEF_VALUE_VERIFY_RETURN(true, false);

  // Detach any dependent values.
  controller()->RemoveDependencies(mutable_value());

  mutable_value()->Clear();
  return true;
}

bool CefDictionaryValueImpl::HasKey(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().HasKey(key);
}

bool CefDictionaryValueImpl::GetKeys(KeyList& keys) {
  CEF_VALUE_VERIFY_RETURN(false, 0);

  base::DictionaryValue::key_iterator it = const_value().begin_keys();
  for (; it != const_value().end_keys(); ++it)
    keys.push_back(*it);

  return true;
}

bool CefDictionaryValueImpl::Remove(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  return RemoveInternal(key);
}

CefValueType CefDictionaryValueImpl::GetType(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, VTYPE_INVALID);

  base::Value* out_value = NULL;
  if (const_value().GetWithoutPathExpansion(key, &out_value)) {
    switch (out_value->GetType()) {
      case base::Value::TYPE_NULL:
        return VTYPE_NULL;
      case base::Value::TYPE_BOOLEAN:
        return VTYPE_BOOL;
      case base::Value::TYPE_INTEGER:
        return VTYPE_INT;
      case base::Value::TYPE_DOUBLE:
        return VTYPE_DOUBLE;
      case base::Value::TYPE_STRING:
        return VTYPE_STRING;
      case base::Value::TYPE_BINARY:
        return VTYPE_BINARY;
      case base::Value::TYPE_DICTIONARY:
        return VTYPE_DICTIONARY;
      case base::Value::TYPE_LIST:
        return VTYPE_LIST;
    }
  }

  return VTYPE_INVALID;
}

bool CefDictionaryValueImpl::GetBool(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, false);

  base::Value* out_value = NULL;
  bool ret_value = false;

  if (const_value().GetWithoutPathExpansion(key, &out_value))
    out_value->GetAsBoolean(&ret_value);

  return ret_value;
}

int CefDictionaryValueImpl::GetInt(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, 0);

  base::Value* out_value = NULL;
  int ret_value = 0;

  if (const_value().GetWithoutPathExpansion(key, &out_value))
    out_value->GetAsInteger(&ret_value);

  return ret_value;
}

double CefDictionaryValueImpl::GetDouble(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, 0);

  base::Value* out_value = NULL;
  double ret_value = 0;

  if (const_value().GetWithoutPathExpansion(key, &out_value))
    out_value->GetAsDouble(&ret_value);

  return ret_value;
}

CefString CefDictionaryValueImpl::GetString(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, CefString());

  base::Value* out_value = NULL;
  string16 ret_value;

  if (const_value().GetWithoutPathExpansion(key, &out_value))
    out_value->GetAsString(&ret_value);

  return ret_value;
}

CefRefPtr<CefBinaryValue> CefDictionaryValueImpl::GetBinary(
    const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  base::Value* out_value = NULL;

  if (const_value().GetWithoutPathExpansion(key, &out_value) &&
      out_value->IsType(base::Value::TYPE_BINARY)) {
    base::BinaryValue* binary_value =
        static_cast<base::BinaryValue*>(out_value);
    return CefBinaryValueImpl::GetOrCreateRef(binary_value,
        const_cast<base::DictionaryValue*>(&const_value()), controller());
  }

  return NULL;
}

CefRefPtr<CefDictionaryValue> CefDictionaryValueImpl::GetDictionary(
    const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  base::Value* out_value = NULL;

  if (const_value().GetWithoutPathExpansion(key, &out_value) &&
      out_value->IsType(base::Value::TYPE_DICTIONARY)) {
    base::DictionaryValue* dict_value =
        static_cast<base::DictionaryValue*>(out_value);
    return CefDictionaryValueImpl::GetOrCreateRef(
        dict_value,
        const_cast<base::DictionaryValue*>(&const_value()),
        read_only(),
        controller());
  }

  return NULL;
}

CefRefPtr<CefListValue> CefDictionaryValueImpl::GetList(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  base::Value* out_value = NULL;

  if (const_value().GetWithoutPathExpansion(key, &out_value) &&
      out_value->IsType(base::Value::TYPE_LIST)) {
    base::ListValue* list_value = static_cast<base::ListValue*>(out_value);
    return CefListValueImpl::GetOrCreateRef(
        list_value,
        const_cast<base::DictionaryValue*>(&const_value()),
        read_only(),
        controller());
  }

  return NULL;
}

bool CefDictionaryValueImpl::SetNull(const CefString& key) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);
  mutable_value()->SetWithoutPathExpansion(key, base::Value::CreateNullValue());
  return true;
}

bool CefDictionaryValueImpl::SetBool(const CefString& key, bool value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);
  mutable_value()->SetWithoutPathExpansion(key,
      base::Value::CreateBooleanValue(value));
  return true;
}

bool CefDictionaryValueImpl::SetInt(const CefString& key, int value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);
  mutable_value()->SetWithoutPathExpansion(key,
      base::Value::CreateIntegerValue(value));
  return true;
}

bool CefDictionaryValueImpl::SetDouble(const CefString& key, double value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);
  mutable_value()->SetWithoutPathExpansion(key,
      base::Value::CreateDoubleValue(value));
  return true;
}

bool CefDictionaryValueImpl::SetString(const CefString& key,
                                       const CefString& value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);
  mutable_value()->SetWithoutPathExpansion(key,
      base::Value::CreateStringValue(value.ToString16()));
  return true;
}

bool CefDictionaryValueImpl::SetBinary(const CefString& key,
                                       CefRefPtr<CefBinaryValue> value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);

  CefBinaryValueImpl* impl = static_cast<CefBinaryValueImpl*>(value.get());
  DCHECK(impl);

  mutable_value()->SetWithoutPathExpansion(key,
      impl->CopyOrDetachValue(controller()));
  return true;
}

bool CefDictionaryValueImpl::SetDictionary(
    const CefString& key, CefRefPtr<CefDictionaryValue> value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);

  CefDictionaryValueImpl* impl =
      static_cast<CefDictionaryValueImpl*>(value.get());
  DCHECK(impl);

  mutable_value()->SetWithoutPathExpansion(key,
      impl->CopyOrDetachValue(controller()));
  return true;
}

bool CefDictionaryValueImpl::SetList(const CefString& key,
                                     CefRefPtr<CefListValue> value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  RemoveInternal(key);

  CefListValueImpl* impl = static_cast<CefListValueImpl*>(value.get());
  DCHECK(impl);

  mutable_value()->SetWithoutPathExpansion(key,
      impl->CopyOrDetachValue(controller()));
  return true;
}

bool CefDictionaryValueImpl::RemoveInternal(const CefString& key) {
  base::Value* out_value = NULL;
  if (!mutable_value()->RemoveWithoutPathExpansion(key, &out_value))
    return false;

  // Remove the value.
  controller()->Remove(out_value, true);

  // Only list and dictionary types may have dependencies.
  if (out_value->IsType(base::Value::TYPE_LIST) ||
      out_value->IsType(base::Value::TYPE_DICTIONARY)) {
    controller()->RemoveDependencies(out_value);
  }

  delete out_value;
  return true;
}

CefDictionaryValueImpl::CefDictionaryValueImpl(
    base::DictionaryValue* value,
    void* parent_value,
    ValueMode value_mode,
    bool read_only,
    CefValueController* controller)
  : CefValueBase<CefDictionaryValue, base::DictionaryValue>(
        value, parent_value, value_mode, read_only, controller) {
}


// CefListValueImpl implementation.

// static
CefRefPtr<CefListValue> CefListValue::Create() {
  return new CefListValueImpl(new base::ListValue(),
      NULL, CefListValueImpl::kOwnerWillDelete, false, NULL);
}

// static
CefRefPtr<CefListValue> CefListValueImpl::GetOrCreateRef(
    base::ListValue* value,
    void* parent_value,
    bool read_only,
    CefValueController* controller) {
  CefValueController::Object* object = controller->Get(value);
  if (object)
    return static_cast<CefListValueImpl*>(object);

  return new CefListValueImpl(value, parent_value,
      CefListValueImpl::kReference, read_only, controller);
}

base::ListValue* CefListValueImpl::CopyValue() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);
  return const_value().DeepCopy();
}

base::ListValue* CefListValueImpl::CopyOrDetachValue(
    CefValueController* new_controller) {
  base::ListValue* new_value;

  if (!will_delete()) {
    // Copy the value.
    new_value = CopyValue();
  } else {
    // Take ownership of the value.
    new_value = Detach(new_controller);
  }

  DCHECK(new_value);
  return new_value;
}

bool CefListValueImpl::IsValid() {
  return !detached();
}

bool CefListValueImpl::IsOwned() {
  return !will_delete();
}

bool CefListValueImpl::IsReadOnly() {
  return read_only();
}

CefRefPtr<CefListValue> CefListValueImpl::Copy() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  return new CefListValueImpl(const_value().DeepCopy(), NULL,
      CefListValueImpl::kOwnerWillDelete, false, NULL);
}

bool CefListValueImpl::SetSize(size_t size) {
  CEF_VALUE_VERIFY_RETURN(true, false);

  size_t current_size = const_value().GetSize();
  if (size < current_size) {
    // Clean up any values above the requested size.
    for (size_t i = current_size-1; i >= size; --i)
       RemoveInternal(i);
  } else if (size > 0) {
    // Expand the list size.
    mutable_value()->Set(size-1, base::Value::CreateNullValue());
  }
  return true;
}

size_t CefListValueImpl::GetSize() {
  CEF_VALUE_VERIFY_RETURN(false, 0);
  return const_value().GetSize();
}

bool CefListValueImpl::Clear() {
  CEF_VALUE_VERIFY_RETURN(true, false);

  // Detach any dependent values.
  controller()->RemoveDependencies(mutable_value());

  mutable_value()->Clear();
  return true;
}

bool CefListValueImpl::Remove(int index) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  return RemoveInternal(index);
}

CefValueType CefListValueImpl::GetType(int index) {
  CEF_VALUE_VERIFY_RETURN(false, VTYPE_INVALID);

  base::Value* out_value = NULL;
  if (const_value().Get(index, &out_value)) {
    switch (out_value->GetType()) {
      case base::Value::TYPE_NULL:
        return VTYPE_NULL;
      case base::Value::TYPE_BOOLEAN:
        return VTYPE_BOOL;
      case base::Value::TYPE_INTEGER:
        return VTYPE_INT;
      case base::Value::TYPE_DOUBLE:
        return VTYPE_DOUBLE;
      case base::Value::TYPE_STRING:
        return VTYPE_STRING;
      case base::Value::TYPE_BINARY:
        return VTYPE_BINARY;
      case base::Value::TYPE_DICTIONARY:
        return VTYPE_DICTIONARY;
      case base::Value::TYPE_LIST:
        return VTYPE_LIST;
    }
  }

  return VTYPE_INVALID;
}

bool CefListValueImpl::GetBool(int index) {
  CEF_VALUE_VERIFY_RETURN(false, false);

  base::Value* out_value = NULL;
  bool ret_value = false;

  if (const_value().Get(index, &out_value))
    out_value->GetAsBoolean(&ret_value);

  return ret_value;
}

int CefListValueImpl::GetInt(int index) {
  CEF_VALUE_VERIFY_RETURN(false, 0);

  base::Value* out_value = NULL;
  int ret_value = 0;

  if (const_value().Get(index, &out_value))
    out_value->GetAsInteger(&ret_value);

  return ret_value;
}

double CefListValueImpl::GetDouble(int index) {
  CEF_VALUE_VERIFY_RETURN(false, 0);

  base::Value* out_value = NULL;
  double ret_value = 0;

  if (const_value().Get(index, &out_value))
    out_value->GetAsDouble(&ret_value);

  return ret_value;
}

CefString CefListValueImpl::GetString(int index) {
  CEF_VALUE_VERIFY_RETURN(false, CefString());

  base::Value* out_value = NULL;
  string16 ret_value;

  if (const_value().Get(index, &out_value))
    out_value->GetAsString(&ret_value);

  return ret_value;
}

CefRefPtr<CefBinaryValue> CefListValueImpl::GetBinary(int index) {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  base::Value* out_value = NULL;

  if (const_value().Get(index, &out_value) &&
      out_value->IsType(base::Value::TYPE_BINARY)) {
    base::BinaryValue* binary_value =
        static_cast<base::BinaryValue*>(out_value);
    return CefBinaryValueImpl::GetOrCreateRef(binary_value,
        const_cast<base::ListValue*>(&const_value()), controller());
  }

  return NULL;
}

CefRefPtr<CefDictionaryValue> CefListValueImpl::GetDictionary(int index) {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  base::Value* out_value = NULL;

  if (const_value().Get(index, &out_value) &&
      out_value->IsType(base::Value::TYPE_DICTIONARY)) {
    base::DictionaryValue* dict_value =
        static_cast<base::DictionaryValue*>(out_value);
    return CefDictionaryValueImpl::GetOrCreateRef(
        dict_value,
        const_cast<base::ListValue*>(&const_value()),
        read_only(),
        controller());
  }

  return NULL;
}

CefRefPtr<CefListValue> CefListValueImpl::GetList(int index) {
  CEF_VALUE_VERIFY_RETURN(false, NULL);

  base::Value* out_value = NULL;

  if (const_value().Get(index, &out_value) &&
      out_value->IsType(base::Value::TYPE_LIST)) {
    base::ListValue* list_value = static_cast<base::ListValue*>(out_value);
    return CefListValueImpl::GetOrCreateRef(
        list_value,
        const_cast<base::ListValue*>(&const_value()),
        read_only(),
        controller());
  }

  return NULL;
}

bool CefListValueImpl::SetNull(int index) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  base::Value* new_value = base::Value::CreateNullValue();
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::SetBool(int index, bool value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  base::Value* new_value = base::Value::CreateBooleanValue(value);
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::SetInt(int index, int value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  base::Value* new_value = base::Value::CreateIntegerValue(value);
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::SetDouble(int index, double value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  base::Value* new_value = base::Value::CreateDoubleValue(value);
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::SetString(int index, const CefString& value) {
  CEF_VALUE_VERIFY_RETURN(true, false);
  base::Value* new_value = base::Value::CreateStringValue(value.ToString16());
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::SetBinary(int index, CefRefPtr<CefBinaryValue> value) {
  CEF_VALUE_VERIFY_RETURN(true, false);

  CefBinaryValueImpl* impl = static_cast<CefBinaryValueImpl*>(value.get());
  DCHECK(impl);

  base::Value* new_value = impl->CopyOrDetachValue(controller());
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::SetDictionary(int index,
                                     CefRefPtr<CefDictionaryValue> value) {
  CEF_VALUE_VERIFY_RETURN(true, false);

  CefDictionaryValueImpl* impl =
      static_cast<CefDictionaryValueImpl*>(value.get());
  DCHECK(impl);

  base::Value* new_value = impl->CopyOrDetachValue(controller());
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::SetList(int index, CefRefPtr<CefListValue> value) {
  CEF_VALUE_VERIFY_RETURN(true, false);

  CefListValueImpl* impl = static_cast<CefListValueImpl*>(value.get());
  DCHECK(impl);

  base::Value* new_value = impl->CopyOrDetachValue(controller());
  if (RemoveInternal(index))
    mutable_value()->Insert(index, new_value);
  else
    mutable_value()->Set(index, new_value);
  return true;
}

bool CefListValueImpl::RemoveInternal(int index) {
  base::Value* out_value = NULL;
  if (!mutable_value()->Remove(index, &out_value))
    return false;

  // Remove the value.
  controller()->Remove(out_value, true);

  // Only list and dictionary types may have dependencies.
  if (out_value->IsType(base::Value::TYPE_LIST) ||
      out_value->IsType(base::Value::TYPE_DICTIONARY)) {
    controller()->RemoveDependencies(out_value);
  }

  delete out_value;
  return true;
}

CefListValueImpl::CefListValueImpl(
    base::ListValue* value,
    void* parent_value,
    ValueMode value_mode,
    bool read_only,
    CefValueController* controller)
  : CefValueBase<CefListValue, base::ListValue>(
        value, parent_value, value_mode, read_only, controller) {
}
