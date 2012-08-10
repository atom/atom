// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_task.h"
#include "include/cef_values.h"
#include "tests/unittests/test_handler.h"
#include "tests/unittests/test_util.h"
#include "testing/gtest/include/gtest/gtest.h"


namespace {

// Dictionary test keys.
const char* kNullKey = "null_key";
const char* kBoolKey = "bool_key";
const char* kIntKey = "int_key";
const char* kDoubleKey = "double_key";
const char* kStringKey = "string_key";
const char* kBinaryKey = "binary_key";
const char* kDictionaryKey = "dict_key";
const char* kListKey = "list_key";

// List test indexes.
enum {
  kNullIndex = 0,
  kBoolIndex,
  kIntIndex,
  kDoubleIndex,
  kStringIndex,
  kBinaryIndex,
  kDictionaryIndex,
  kListIndex,
};

// Dictionary/list test values.
const bool kBoolValue = true;
const int kIntValue = 12;
const double kDoubleValue = 4.5432;
const char* kStringValue = "My string value";


// BINARY TEST HELPERS

// Test a binary value.
void TestBinary(CefRefPtr<CefBinaryValue> value, char* data, size_t data_size) {
  // Testing requires strings longer than 15 characters.
  EXPECT_GT(data_size, (size_t)15);

  EXPECT_EQ(data_size, value->GetSize());

  char* buff = new char[data_size+1];
  char old_char;

  // Test full read.
  memset(buff, 0, data_size+1);
  EXPECT_EQ(data_size, value->GetData(buff, data_size, 0));
  EXPECT_TRUE(!strcmp(buff, data));

  // Test partial read with offset.
  memset(buff, 0, data_size+1);
  old_char = data[15];
  data[15] = 0;
  EXPECT_EQ((size_t)10, value->GetData(buff, 10, 5));
  EXPECT_TRUE(!strcmp(buff, data+5));
  data[15] = old_char;

  // Test that changes to the original data have no effect.
  memset(buff, 0, data_size+1);
  old_char = data[0];
  data[0] = '.';
  EXPECT_EQ((size_t)1, value->GetData(buff, 1, 0));
  EXPECT_EQ(old_char, buff[0]);
  data[0] = old_char;

  // Test copy.
  CefRefPtr<CefBinaryValue> copy = value->Copy();
  TestBinaryEqual(copy, value);

  delete [] buff;
}

// Used to test access of binary data on a different thread.
class BinaryTask : public CefTask {
 public:
  BinaryTask(CefRefPtr<CefBinaryValue> value, char* data, size_t data_size)
    : value_(value),
      data_(data),
      data_size_(data_size) {}

  virtual void Execute(CefThreadId threadId) OVERRIDE {
    TestBinary(value_, data_, data_size_);
  }

 private:
  CefRefPtr<CefBinaryValue> value_;
  char* data_;
  size_t data_size_;

  IMPLEMENT_REFCOUNTING(BinaryTask);
};


// DICTIONARY TEST HELPERS

// Test dictionary null value.
void TestDictionaryNull(CefRefPtr<CefDictionaryValue> value) {
  EXPECT_FALSE(value->HasKey(kNullKey));
  EXPECT_TRUE(value->SetNull(kNullKey));
  EXPECT_TRUE(value->HasKey(kNullKey));
  EXPECT_EQ(VTYPE_NULL, value->GetType(kNullKey));
}

// Test dictionary bool value.
void TestDictionaryBool(CefRefPtr<CefDictionaryValue> value) {
  EXPECT_FALSE(value->HasKey(kBoolKey));
  EXPECT_TRUE(value->SetBool(kBoolKey, kBoolValue));
  EXPECT_TRUE(value->HasKey(kBoolKey));
  EXPECT_EQ(VTYPE_BOOL, value->GetType(kBoolKey));
  EXPECT_EQ(kBoolValue, value->GetBool(kBoolKey));
}

// Test dictionary int value.
void TestDictionaryInt(CefRefPtr<CefDictionaryValue> value) {
  EXPECT_FALSE(value->HasKey(kIntKey));
  EXPECT_TRUE(value->SetInt(kIntKey, kIntValue));
  EXPECT_TRUE(value->HasKey(kIntKey));
  EXPECT_EQ(VTYPE_INT, value->GetType(kIntKey));
  EXPECT_EQ(kIntValue, value->GetInt(kIntKey));
}

// Test dictionary double value.
void TestDictionaryDouble(CefRefPtr<CefDictionaryValue> value) {
  EXPECT_FALSE(value->HasKey(kDoubleKey));
  EXPECT_TRUE(value->SetDouble(kDoubleKey, kDoubleValue));
  EXPECT_TRUE(value->HasKey(kDoubleKey));
  EXPECT_EQ(VTYPE_DOUBLE, value->GetType(kDoubleKey));
  EXPECT_EQ(kDoubleValue, value->GetDouble(kDoubleKey));
}

// Test dictionary string value.
void TestDictionaryString(CefRefPtr<CefDictionaryValue> value) {
  EXPECT_FALSE(value->HasKey(kStringKey));
  EXPECT_TRUE(value->SetString(kStringKey, kStringValue));
  EXPECT_TRUE(value->HasKey(kStringKey));
  EXPECT_EQ(VTYPE_STRING, value->GetType(kStringKey));
  EXPECT_EQ(kStringValue, value->GetString(kStringKey).ToString());
}

// Test dictionary binary value.
void TestDictionaryBinary(CefRefPtr<CefDictionaryValue> value,
                          char* binary_data, size_t binary_data_size,
                          CefRefPtr<CefBinaryValue>& binary_value) {
  binary_value = CefBinaryValue::Create(binary_data, binary_data_size);
  EXPECT_TRUE(binary_value.get());
  EXPECT_TRUE(binary_value->IsValid());
  EXPECT_FALSE(binary_value->IsOwned());
  EXPECT_FALSE(value->HasKey(kBinaryKey));
  EXPECT_TRUE(value->SetBinary(kBinaryKey, binary_value));
  EXPECT_FALSE(binary_value->IsValid());  // Value should be detached
  EXPECT_TRUE(value->HasKey(kBinaryKey));
  EXPECT_EQ(VTYPE_BINARY, value->GetType(kBinaryKey));
  binary_value = value->GetBinary(kBinaryKey);
  EXPECT_TRUE(binary_value.get());
  EXPECT_TRUE(binary_value->IsValid());
  EXPECT_TRUE(binary_value->IsOwned());
  TestBinary(binary_value, binary_data, binary_data_size);
}

// Test dictionary dictionary value.
void TestDictionaryDictionary(CefRefPtr<CefDictionaryValue> value,
                              CefRefPtr<CefDictionaryValue>& dictionary_value) {
  dictionary_value = CefDictionaryValue::Create();
  EXPECT_TRUE(dictionary_value.get());
  EXPECT_TRUE(dictionary_value->IsValid());
  EXPECT_FALSE(dictionary_value->IsOwned());
  EXPECT_FALSE(dictionary_value->IsReadOnly());
  EXPECT_TRUE(dictionary_value->SetInt(kIntKey, kIntValue));
  EXPECT_EQ((size_t)1, dictionary_value->GetSize());
  EXPECT_FALSE(value->HasKey(kDictionaryKey));
  EXPECT_TRUE(value->SetDictionary(kDictionaryKey, dictionary_value));
  EXPECT_FALSE(dictionary_value->IsValid());  // Value should be detached
  EXPECT_TRUE(value->HasKey(kDictionaryKey));
  EXPECT_EQ(VTYPE_DICTIONARY, value->GetType(kDictionaryKey));
  dictionary_value = value->GetDictionary(kDictionaryKey);
  EXPECT_TRUE(dictionary_value.get());
  EXPECT_TRUE(dictionary_value->IsValid());
  EXPECT_TRUE(dictionary_value->IsOwned());
  EXPECT_FALSE(dictionary_value->IsReadOnly());
  EXPECT_EQ((size_t)1, dictionary_value->GetSize());
  EXPECT_EQ(kIntValue, dictionary_value->GetInt(kIntKey));
}

// Test dictionary list value.
void TestDictionaryList(CefRefPtr<CefDictionaryValue> value,
                        CefRefPtr<CefListValue>& list_value) {
  list_value = CefListValue::Create();
  EXPECT_TRUE(list_value.get());
  EXPECT_TRUE(list_value->IsValid());
  EXPECT_FALSE(list_value->IsOwned());
  EXPECT_FALSE(list_value->IsReadOnly());
  EXPECT_TRUE(list_value->SetInt(0, kIntValue));
  EXPECT_EQ((size_t)1, list_value->GetSize());
  EXPECT_FALSE(value->HasKey(kListKey));
  EXPECT_TRUE(value->SetList(kListKey, list_value));
  EXPECT_FALSE(list_value->IsValid());  // Value should be detached
  EXPECT_TRUE(value->HasKey(kListKey));
  EXPECT_EQ(VTYPE_LIST, value->GetType(kListKey));
  list_value = value->GetList(kListKey);
  EXPECT_TRUE(list_value.get());
  EXPECT_TRUE(list_value->IsValid());
  EXPECT_TRUE(list_value->IsOwned());
  EXPECT_FALSE(list_value->IsReadOnly());
  EXPECT_EQ((size_t)1, list_value->GetSize());
  EXPECT_EQ(kIntValue, list_value->GetInt(0));
}

// Test dictionary value.
void TestDictionary(CefRefPtr<CefDictionaryValue> value,
                    char* binary_data, size_t binary_data_size) {
  CefRefPtr<CefBinaryValue> binary_value;
  CefRefPtr<CefDictionaryValue> dictionary_value;
  CefRefPtr<CefListValue> list_value;

  // Test the size.
  EXPECT_EQ((size_t)0, value->GetSize());

  TestDictionaryNull(value);
  TestDictionaryBool(value);
  TestDictionaryInt(value);
  TestDictionaryDouble(value);
  TestDictionaryString(value);
  TestDictionaryBinary(value, binary_data, binary_data_size, binary_value);
  TestDictionaryDictionary(value, dictionary_value);
  TestDictionaryList(value, list_value);

  // Test the size.
  EXPECT_EQ((size_t)8, value->GetSize());

  // Test copy.
  CefRefPtr<CefDictionaryValue> copy = value->Copy(false);
  TestDictionaryEqual(value, copy);

  // Test removal.
  EXPECT_TRUE(value->Remove(kNullKey));
  EXPECT_FALSE(value->HasKey(kNullKey));

  EXPECT_TRUE(value->Remove(kBoolKey));
  EXPECT_FALSE(value->HasKey(kBoolKey));

  EXPECT_TRUE(value->Remove(kIntKey));
  EXPECT_FALSE(value->HasKey(kIntKey));

  EXPECT_TRUE(value->Remove(kDoubleKey));
  EXPECT_FALSE(value->HasKey(kDoubleKey));

  EXPECT_TRUE(value->Remove(kStringKey));
  EXPECT_FALSE(value->HasKey(kStringKey));

  EXPECT_TRUE(value->Remove(kBinaryKey));
  EXPECT_FALSE(value->HasKey(kBinaryKey));
  EXPECT_FALSE(binary_value->IsValid());  // Value should be detached

  EXPECT_TRUE(value->Remove(kDictionaryKey));
  EXPECT_FALSE(value->HasKey(kDictionaryKey));
  EXPECT_FALSE(dictionary_value->IsValid());  // Value should be detached

  EXPECT_TRUE(value->Remove(kListKey));
  EXPECT_FALSE(value->HasKey(kListKey));
  EXPECT_FALSE(list_value->IsValid());  // Value should be detached

  // Test the size.
  EXPECT_EQ((size_t)0, value->GetSize());

  // Re-add some values.
  TestDictionaryNull(value);
  TestDictionaryBool(value);
  TestDictionaryDictionary(value, dictionary_value);

  // Test the size.
  EXPECT_EQ((size_t)3, value->GetSize());

  // Clear the values.
  EXPECT_TRUE(value->Clear());
  EXPECT_EQ((size_t)0, value->GetSize());
  EXPECT_FALSE(dictionary_value->IsValid());  // Value should be detached
}

// Used to test access of dictionary data on a different thread.
class DictionaryTask : public CefTask {
 public:
  DictionaryTask(CefRefPtr<CefDictionaryValue> value, char* binary_data,
                 size_t binary_data_size)
    : value_(value),
      binary_data_(binary_data),
      binary_data_size_(binary_data_size)  {}

  virtual void Execute(CefThreadId threadId) OVERRIDE {
    TestDictionary(value_, binary_data_, binary_data_size_);
  }

 private:
  CefRefPtr<CefDictionaryValue> value_;
  char* binary_data_;
  size_t binary_data_size_;

  IMPLEMENT_REFCOUNTING(DictionaryTask);
};


// LIST TEST HELPERS

// Test list null value.
void TestListNull(CefRefPtr<CefListValue> value, int index) {
  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetNull(index));
  EXPECT_EQ(VTYPE_NULL, value->GetType(index));
}

// Test list bool value.
void TestListBool(CefRefPtr<CefListValue> value, int index) {
  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetBool(index, kBoolValue));
  EXPECT_EQ(VTYPE_BOOL, value->GetType(index));
  EXPECT_EQ(kBoolValue, value->GetBool(index));
}

// Test list int value.
void TestListInt(CefRefPtr<CefListValue> value, int index) {
  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetInt(index, kIntValue));
  EXPECT_EQ(VTYPE_INT, value->GetType(index));
  EXPECT_EQ(kIntValue, value->GetInt(index));
}

// Test list double value.
void TestListDouble(CefRefPtr<CefListValue> value, int index) {
  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetDouble(index, kDoubleValue));
  EXPECT_EQ(VTYPE_DOUBLE, value->GetType(index));
  EXPECT_EQ(kDoubleValue, value->GetDouble(index));
}

// Test list string value.
void TestListString(CefRefPtr<CefListValue> value, int index) {
  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetString(index, kStringValue));
  EXPECT_EQ(VTYPE_STRING, value->GetType(index));
  EXPECT_EQ(kStringValue, value->GetString(index).ToString());
}

// Test list binary value.
void TestListBinary(CefRefPtr<CefListValue> value, int index,
                          char* binary_data, size_t binary_data_size,
                          CefRefPtr<CefBinaryValue>& binary_value) {
  binary_value = CefBinaryValue::Create(binary_data, binary_data_size);
  EXPECT_TRUE(binary_value.get());
  EXPECT_TRUE(binary_value->IsValid());
  EXPECT_FALSE(binary_value->IsOwned());

  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetBinary(index, binary_value));
  EXPECT_FALSE(binary_value->IsValid());  // Value should be detached
  EXPECT_EQ(VTYPE_BINARY, value->GetType(index));
  binary_value = value->GetBinary(index);
  EXPECT_TRUE(binary_value.get());
  EXPECT_TRUE(binary_value->IsValid());
  EXPECT_TRUE(binary_value->IsOwned());
  TestBinary(binary_value, binary_data, binary_data_size);
}

// Test list dictionary value.
void TestListDictionary(CefRefPtr<CefListValue> value, int index,
                        CefRefPtr<CefDictionaryValue>& dictionary_value) {
  dictionary_value = CefDictionaryValue::Create();
  EXPECT_TRUE(dictionary_value.get());
  EXPECT_TRUE(dictionary_value->IsValid());
  EXPECT_FALSE(dictionary_value->IsOwned());
  EXPECT_FALSE(dictionary_value->IsReadOnly());
  EXPECT_TRUE(dictionary_value->SetInt(kIntKey, kIntValue));
  EXPECT_EQ((size_t)1, dictionary_value->GetSize());

  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetDictionary(index, dictionary_value));
  EXPECT_FALSE(dictionary_value->IsValid());  // Value should be detached
  EXPECT_EQ(VTYPE_DICTIONARY, value->GetType(index));
  dictionary_value = value->GetDictionary(index);
  EXPECT_TRUE(dictionary_value.get());
  EXPECT_TRUE(dictionary_value->IsValid());
  EXPECT_TRUE(dictionary_value->IsOwned());
  EXPECT_FALSE(dictionary_value->IsReadOnly());
  EXPECT_EQ((size_t)1, dictionary_value->GetSize());
  EXPECT_EQ(kIntValue, dictionary_value->GetInt(kIntKey));
}

// Test list list value.
void TestListList(CefRefPtr<CefListValue> value, int index,
                  CefRefPtr<CefListValue>& list_value) {
  list_value = CefListValue::Create();
  EXPECT_TRUE(list_value.get());
  EXPECT_TRUE(list_value->IsValid());
  EXPECT_FALSE(list_value->IsOwned());
  EXPECT_FALSE(list_value->IsReadOnly());
  EXPECT_TRUE(list_value->SetInt(0, kIntValue));
  EXPECT_EQ((size_t)1, list_value->GetSize());

  CefValueType type = value->GetType(index);
  EXPECT_TRUE(type == VTYPE_INVALID || type == VTYPE_NULL);

  EXPECT_TRUE(value->SetList(index, list_value));
  EXPECT_FALSE(list_value->IsValid());  // Value should be detached
  EXPECT_EQ(VTYPE_LIST, value->GetType(index));
  list_value = value->GetList(index);
  EXPECT_TRUE(list_value.get());
  EXPECT_TRUE(list_value->IsValid());
  EXPECT_TRUE(list_value->IsOwned());
  EXPECT_FALSE(list_value->IsReadOnly());
  EXPECT_EQ((size_t)1, list_value->GetSize());
  EXPECT_EQ(kIntValue, list_value->GetInt(0));
}

// Test list value.
void TestList(CefRefPtr<CefListValue> value,
              char* binary_data, size_t binary_data_size) {
  CefRefPtr<CefBinaryValue> binary_value;
  CefRefPtr<CefDictionaryValue> dictionary_value;
  CefRefPtr<CefListValue> list_value;

  // Test the size.
  EXPECT_EQ((size_t)0, value->GetSize());

  // Set the size.
  EXPECT_TRUE(value->SetSize(8));
  EXPECT_EQ((size_t)8, value->GetSize());

  EXPECT_EQ(VTYPE_NULL, value->GetType(kNullIndex));
  TestListNull(value, kNullIndex);
  EXPECT_EQ(VTYPE_NULL, value->GetType(kBoolIndex));
  TestListBool(value, kBoolIndex);
  EXPECT_EQ(VTYPE_NULL, value->GetType(kIntIndex));
  TestListInt(value, kIntIndex);
  EXPECT_EQ(VTYPE_NULL, value->GetType(kDoubleIndex));
  TestListDouble(value, kDoubleIndex);
  EXPECT_EQ(VTYPE_NULL, value->GetType(kStringIndex));
  TestListString(value, kStringIndex);
  EXPECT_EQ(VTYPE_NULL, value->GetType(kBinaryIndex));
  TestListBinary(value, kBinaryIndex, binary_data, binary_data_size,
      binary_value);
  EXPECT_EQ(VTYPE_NULL, value->GetType(kDictionaryIndex));
  TestListDictionary(value, kDictionaryIndex, dictionary_value);
  EXPECT_EQ(VTYPE_NULL, value->GetType(kListIndex));
  TestListList(value, kListIndex, list_value);

  // Test the size.
  EXPECT_EQ((size_t)8, value->GetSize());

  // Test copy.
  CefRefPtr<CefListValue> copy = value->Copy();
  TestListEqual(value, copy);

  // Test removal (in reverse order so indexes stay valid).
  EXPECT_TRUE(value->Remove(kListIndex));
  EXPECT_EQ((size_t)7, value->GetSize());
  EXPECT_FALSE(list_value->IsValid());  // Value should be detached

  EXPECT_TRUE(value->Remove(kDictionaryIndex));
  EXPECT_EQ((size_t)6, value->GetSize());
  EXPECT_FALSE(dictionary_value->IsValid());  // Value should be detached

  EXPECT_TRUE(value->Remove(kBinaryIndex));
  EXPECT_EQ((size_t)5, value->GetSize());
  EXPECT_FALSE(binary_value->IsValid());  // Value should be detached

  EXPECT_TRUE(value->Remove(kStringIndex));
  EXPECT_EQ((size_t)4, value->GetSize());

  EXPECT_TRUE(value->Remove(kDoubleIndex));
  EXPECT_EQ((size_t)3, value->GetSize());

  EXPECT_TRUE(value->Remove(kIntIndex));
  EXPECT_EQ((size_t)2, value->GetSize());

  EXPECT_TRUE(value->Remove(kBoolIndex));
  EXPECT_EQ((size_t)1, value->GetSize());

  EXPECT_TRUE(value->Remove(kNullIndex));
  EXPECT_EQ((size_t)0, value->GetSize());

  // Re-add some values.
  EXPECT_EQ(VTYPE_INVALID, value->GetType(0));
  TestListNull(value, 0);
  EXPECT_EQ(VTYPE_INVALID, value->GetType(1));
  TestListBool(value, 1);
  EXPECT_EQ(VTYPE_INVALID, value->GetType(2));
  TestListList(value, 2, list_value);

  // Test the size.
  EXPECT_EQ((size_t)3, value->GetSize());

  // Clear the values.
  EXPECT_TRUE(value->Clear());
  EXPECT_EQ((size_t)0, value->GetSize());
  EXPECT_FALSE(list_value->IsValid());  // Value should be detached

  // Add some values in random order.
  EXPECT_EQ(VTYPE_INVALID, value->GetType(2));
  TestListInt(value, 2);
  EXPECT_EQ(VTYPE_NULL, value->GetType(0));
  TestListBool(value, 0);
  EXPECT_EQ(VTYPE_NULL, value->GetType(1));
  TestListList(value, 1, list_value);

  EXPECT_EQ(VTYPE_BOOL, value->GetType(0));
  EXPECT_EQ(VTYPE_LIST, value->GetType(1));
  EXPECT_EQ(VTYPE_INT, value->GetType(2));

  // Test the size.
  EXPECT_EQ((size_t)3, value->GetSize());

  // Clear some values.
  EXPECT_TRUE(value->SetSize(1));
  EXPECT_EQ((size_t)1, value->GetSize());
  EXPECT_FALSE(list_value->IsValid());  // Value should be detached

  EXPECT_EQ(VTYPE_BOOL, value->GetType(0));
  EXPECT_EQ(VTYPE_INVALID, value->GetType(1));
  EXPECT_EQ(VTYPE_INVALID, value->GetType(2));

  // Clear all values.
  EXPECT_TRUE(value->Clear());
  EXPECT_EQ((size_t)0, value->GetSize());
}

// Used to test access of list data on a different thread.
class ListTask : public CefTask {
 public:
  ListTask(CefRefPtr<CefListValue> value, char* binary_data,
                 size_t binary_data_size)
    : value_(value),
      binary_data_(binary_data),
      binary_data_size_(binary_data_size)  {}

  virtual void Execute(CefThreadId threadId) OVERRIDE {
    TestList(value_, binary_data_, binary_data_size_);
  }

 private:
  CefRefPtr<CefListValue> value_;
  char* binary_data_;
  size_t binary_data_size_;

  IMPLEMENT_REFCOUNTING(ListTask);
};

}  // namespace


// Test binary value access.
TEST(ValuesTest, BinaryAccess) {
  char data[] = "This is my test data";

  CefRefPtr<CefBinaryValue> value =
      CefBinaryValue::Create(data, sizeof(data)-1);
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());

  // Test on this thread.
  TestBinary(value, data, sizeof(data)-1);
}

// Test binary value access on a different thread.
TEST(ValuesTest, BinaryAccessOtherThread) {
  char data[] = "This is my test data";

  CefRefPtr<CefBinaryValue> value =
      CefBinaryValue::Create(data, sizeof(data)-1);
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());

  // Test on a different thread.
  CefPostTask(TID_UI, new BinaryTask(value, data, sizeof(data)-1));
  WaitForUIThread();
}

// Test dictionary value access.
TEST(ValuesTest, DictionaryAccess) {
  CefRefPtr<CefDictionaryValue> value = CefDictionaryValue::Create();
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());
  EXPECT_FALSE(value->IsReadOnly());

  char binary_data[] = "This is my test data";

  // Test on this thread.
  TestDictionary(value, binary_data, sizeof(binary_data)-1);
}

// Test dictionary value access on a different thread.
TEST(ValuesTest, DictionaryAccessOtherThread) {
  CefRefPtr<CefDictionaryValue> value = CefDictionaryValue::Create();
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());
  EXPECT_FALSE(value->IsReadOnly());

  char binary_data[] = "This is my test data";

  // Test on a different thread.
  CefPostTask(TID_UI,
      new DictionaryTask(value, binary_data, sizeof(binary_data)-1));
  WaitForUIThread();
}

// Test dictionary value nested detachment
TEST(ValuesTest, DictionaryDetachment) {
  CefRefPtr<CefDictionaryValue> value = CefDictionaryValue::Create();
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());
  EXPECT_FALSE(value->IsReadOnly());

  CefRefPtr<CefDictionaryValue> dictionary_value = CefDictionaryValue::Create();
  CefRefPtr<CefDictionaryValue> dictionary_value2 =
      CefDictionaryValue::Create();
  CefRefPtr<CefDictionaryValue> dictionary_value3 =
      CefDictionaryValue::Create();

  dictionary_value2->SetDictionary(kDictionaryKey, dictionary_value3);
  EXPECT_FALSE(dictionary_value3->IsValid());
  dictionary_value->SetDictionary(kDictionaryKey, dictionary_value2);
  EXPECT_FALSE(dictionary_value2->IsValid());
  value->SetDictionary(kDictionaryKey, dictionary_value);
  EXPECT_FALSE(dictionary_value->IsValid());

  dictionary_value = value->GetDictionary(kDictionaryKey);
  EXPECT_TRUE(dictionary_value.get());
  EXPECT_TRUE(dictionary_value->IsValid());

  dictionary_value2 = dictionary_value->GetDictionary(kDictionaryKey);
  EXPECT_TRUE(dictionary_value2.get());
  EXPECT_TRUE(dictionary_value2->IsValid());

  dictionary_value3 = dictionary_value2->GetDictionary(kDictionaryKey);
  EXPECT_TRUE(dictionary_value3.get());
  EXPECT_TRUE(dictionary_value3->IsValid());

  EXPECT_TRUE(value->Remove(kDictionaryKey));
  EXPECT_FALSE(dictionary_value->IsValid());
  EXPECT_FALSE(dictionary_value2->IsValid());
  EXPECT_FALSE(dictionary_value3->IsValid());
}

// Test list value access.
TEST(ValuesTest, ListAccess) {
  CefRefPtr<CefListValue> value = CefListValue::Create();
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());
  EXPECT_FALSE(value->IsReadOnly());

  char binary_data[] = "This is my test data";

  // Test on this thread.
  TestList(value, binary_data, sizeof(binary_data)-1);
}

// Test list value access on a different thread.
TEST(ValuesTest, ListAccessOtherThread) {
  CefRefPtr<CefListValue> value = CefListValue::Create();
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());
  EXPECT_FALSE(value->IsReadOnly());

  char binary_data[] = "This is my test data";

  // Test on a different thread.
  CefPostTask(TID_UI, new ListTask(value, binary_data, sizeof(binary_data)-1));
  WaitForUIThread();
}

// Test list value nested detachment
TEST(ValuesTest, ListDetachment) {
  CefRefPtr<CefListValue> value = CefListValue::Create();
  EXPECT_TRUE(value.get());
  EXPECT_TRUE(value->IsValid());
  EXPECT_FALSE(value->IsOwned());
  EXPECT_FALSE(value->IsReadOnly());

  CefRefPtr<CefListValue> list_value = CefListValue::Create();
  CefRefPtr<CefListValue> list_value2 = CefListValue::Create();
  CefRefPtr<CefListValue> list_value3 = CefListValue::Create();

  list_value2->SetList(0, list_value3);
  EXPECT_FALSE(list_value3->IsValid());
  list_value->SetList(0, list_value2);
  EXPECT_FALSE(list_value2->IsValid());
  value->SetList(0, list_value);
  EXPECT_FALSE(list_value->IsValid());

  list_value = value->GetList(0);
  EXPECT_TRUE(list_value.get());
  EXPECT_TRUE(list_value->IsValid());

  list_value2 = list_value->GetList(0);
  EXPECT_TRUE(list_value2.get());
  EXPECT_TRUE(list_value2->IsValid());

  list_value3 = list_value2->GetList(0);
  EXPECT_TRUE(list_value3.get());
  EXPECT_TRUE(list_value3->IsValid());

  EXPECT_TRUE(value->Remove(0));
  EXPECT_FALSE(list_value->IsValid());
  EXPECT_FALSE(list_value2->IsValid());
  EXPECT_FALSE(list_value3->IsValid());
}
