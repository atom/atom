// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_stream.h"
#include "testing/gtest/include/gtest/gtest.h"

static void VerifyStreamReadBehavior(CefRefPtr<CefStreamReader> stream,
                                     const std::string& contents) {
  int contentSize = static_cast<int>(contents.size());
  const char* contentStr = contents.c_str();

  // Move to the beginning of the stream
  ASSERT_EQ(0, stream->Seek(0, SEEK_SET));
  ASSERT_EQ(0, stream->Tell());

  // Move to the end of the stream
  ASSERT_EQ(0, stream->Seek(0, SEEK_END));
  ASSERT_EQ(contentSize, stream->Tell());

  // Move to the beginning of the stream
  ASSERT_EQ(0, stream->Seek(-contentSize, SEEK_CUR));
  ASSERT_EQ(0, stream->Tell());

  // Read 10 characters at a time and verify the result
  char buff[10];
  int res, read, offset = 0;
  do {
    read = std::min(static_cast<int>(sizeof(buff)), contentSize-offset);
    res = stream->Read(buff, 1, read);
    ASSERT_EQ(read, res);
    ASSERT_TRUE(!memcmp(contentStr+offset, buff, res));
    offset += res;
  } while (offset < contentSize);

  // Read past the end of the file
  stream->Read(buff, 1, 1);
  ASSERT_TRUE(stream->Eof());
}

static void VerifyStreamWriteBehavior(CefRefPtr<CefStreamWriter> stream,
                                      const std::string& contents) {
  int contentSize = static_cast<int>(contents.size());
  const char* contentStr = contents.c_str();

  // Write 10 characters at a time and verify the result
  int res, write, offset = 0;
  do {
    write = std::min(10, contentSize-offset);
    res = stream->Write(contentStr+offset, 1, write);
    ASSERT_EQ(write, res);
    offset += res;
    ASSERT_EQ(offset, stream->Tell());
  } while (offset < contentSize);

  // Move to the beginning of the stream
  ASSERT_EQ(0, stream->Seek(-contentSize, SEEK_CUR));
  ASSERT_EQ(0, stream->Tell());

  // Move to the end of the stream
  ASSERT_EQ(0, stream->Seek(0, SEEK_END));
  ASSERT_EQ(contentSize, stream->Tell());

  // Move to the beginning of the stream
  ASSERT_EQ(0, stream->Seek(0, SEEK_SET));
  ASSERT_EQ(0, stream->Tell());
}

TEST(StreamTest, ReadFile) {
  const char* fileName = "StreamTest.VerifyReadFile.txt";
  CefString fileNameStr = "StreamTest.VerifyReadFile.txt";
  std::string contents = "This is my test\ncontents for the file";

  // Create the file
  FILE* f = NULL;
#ifdef _WIN32
  fopen_s(&f, fileName, "wb");
#else
  f = fopen(fileName, "wb");
#endif
  ASSERT_TRUE(f != NULL);
  ASSERT_EQ((size_t)1, fwrite(contents.c_str(), contents.size(), 1, f));
  fclose(f);

  // Test the stream
  CefRefPtr<CefStreamReader> stream(
      CefStreamReader::CreateForFile(fileNameStr));
  ASSERT_TRUE(stream.get() != NULL);
  VerifyStreamReadBehavior(stream, contents);

  // Release the file pointer
  stream = NULL;

  // Delete the file
#ifdef _WIN32
  ASSERT_EQ(0, _unlink(fileName));
#else
  ASSERT_EQ(0, unlink(fileName));
#endif
}

TEST(StreamTest, ReadData) {
  std::string contents = "This is my test\ncontents for the file";

  // Test the stream
  CefRefPtr<CefStreamReader> stream(
      CefStreamReader::CreateForData(
          static_cast<void*>(const_cast<char*>(contents.c_str())),
          contents.size()));
  ASSERT_TRUE(stream.get() != NULL);
  VerifyStreamReadBehavior(stream, contents);
}

TEST(StreamTest, WriteFile) {
  const char* fileName = "StreamTest.VerifyWriteFile.txt";
  CefString fileNameStr = "StreamTest.VerifyWriteFile.txt";
  std::string contents = "This is my test\ncontents for the file";

  // Test the stream
  CefRefPtr<CefStreamWriter> stream(
      CefStreamWriter::CreateForFile(fileNameStr));
  ASSERT_TRUE(stream.get() != NULL);
  VerifyStreamWriteBehavior(stream, contents);

  // Release the file pointer
  stream = NULL;

  // Read the file that was written
  FILE* f = NULL;
  char* buff = new char[contents.size()];
#ifdef _WIN32
  fopen_s(&f, fileName, "rb");
#else
  f = fopen(fileName, "rb");
#endif
  ASSERT_TRUE(f != NULL);
  ASSERT_EQ((size_t)1, fread(buff, contents.size(), 1, f));

  // Read past the end of the file
  fgetc(f);
  ASSERT_TRUE(feof(f));
  fclose(f);

  // Verify the file contents
  ASSERT_TRUE(!memcmp(contents.c_str(), buff, contents.size()));
  delete [] buff;

  // Delete the file
#ifdef _WIN32
  ASSERT_EQ(0, _unlink(fileName));
#else
  ASSERT_EQ(0, unlink(fileName));
#endif
}

bool g_ReadHandlerTesterDeleted = false;

class ReadHandlerTester : public CefReadHandler {
 public:
  ReadHandlerTester()
    : read_called_(false),
      read_ptr_(NULL),
      read_size_(0),
      read_n_(0),
      seek_called_(false),
      seek_offset_(0),
      seek_whence_(0),
      tell_called_(false),
      eof_called_(false) {
  }
  virtual ~ReadHandlerTester() {
    g_ReadHandlerTesterDeleted = true;
  }

  virtual size_t Read(void* ptr, size_t size, size_t n) {
    read_called_ = true;
    read_ptr_ = ptr;
    read_size_ = size;
    read_n_ = n;
    return 10;
  }

  virtual int Seek(int64 offset, int whence) {
    seek_called_ = true;
    seek_offset_ = offset;
    seek_whence_ = whence;
    return 10;
  }

  virtual int64 Tell() {
    tell_called_ = true;
    return 10;
  }

  virtual int Eof() {
    eof_called_ = true;
    return 10;
  }

  bool read_called_;
  const void* read_ptr_;
  size_t read_size_;
  size_t read_n_;

  bool seek_called_;
  int64 seek_offset_;
  int seek_whence_;

  bool tell_called_;

  bool eof_called_;

  IMPLEMENT_REFCOUNTING(ReadHandlerTester);
};

TEST(StreamTest, ReadHandler) {
  ReadHandlerTester* handler = new ReadHandlerTester();
  ASSERT_TRUE(handler != NULL);

  CefRefPtr<CefStreamReader> stream(CefStreamReader::CreateForHandler(handler));
  ASSERT_TRUE(stream.get() != NULL);

  // CefReadHandler Read
  const char* read_ptr = "My data";
  size_t read_size = sizeof(read_ptr);
  size_t read_n = 1;
  size_t read_res = stream->Read(
      static_cast<void*>(const_cast<char*>(read_ptr)), read_size, read_n);
  ASSERT_TRUE(handler->read_called_);
  ASSERT_EQ((size_t)10, read_res);
  ASSERT_EQ(read_ptr, handler->read_ptr_);
  ASSERT_EQ(read_size, handler->read_size_);
  ASSERT_EQ(read_n, handler->read_n_);

  // CefReadHandler Seek
  int64 seek_offset = 10;
  int seek_whence = SEEK_CUR;
  int seek_res = stream->Seek(seek_offset, seek_whence);
  ASSERT_TRUE(handler->seek_called_);
  ASSERT_EQ(10, seek_res);
  ASSERT_EQ(seek_offset, handler->seek_offset_);
  ASSERT_EQ(seek_whence, handler->seek_whence_);

  // CefReadHandler Tell
  int64 tell_res = stream->Tell();
  ASSERT_TRUE(handler->tell_called_);
  ASSERT_EQ(10, tell_res);

  // CefReadHandler Eof
  int eof_res = stream->Eof();
  ASSERT_TRUE(handler->eof_called_);
  ASSERT_EQ(10, eof_res);

  // Delete the stream
  stream = NULL;

  // Verify that the handler object was deleted
  ASSERT_TRUE(g_ReadHandlerTesterDeleted);
}

bool g_WriteHandlerTesterDeleted = false;

class WriteHandlerTester : public CefWriteHandler {
 public:
  WriteHandlerTester()
    : write_called_(false),
      write_ptr_(NULL),
      write_size_(0),
      write_n_(0),
      seek_called_(false),
      seek_offset_(0),
      seek_whence_(0),
      tell_called_(false),
      flush_called_(false) {
  }
  virtual ~WriteHandlerTester() {
    g_WriteHandlerTesterDeleted = true;
  }

  virtual size_t Write(const void* ptr, size_t size, size_t n) {
    write_called_ = true;
    write_ptr_ = ptr;
    write_size_ = size;
    write_n_ = n;
    return 10;
  }

  virtual int Seek(int64 offset, int whence) {
    seek_called_ = true;
    seek_offset_ = offset;
    seek_whence_ = whence;
    return 10;
  }

  virtual int64 Tell() {
    tell_called_ = true;
    return 10;
  }

  virtual int Flush() {
    flush_called_ = true;
    return 10;
  }

  bool write_called_;
  const void* write_ptr_;
  size_t write_size_;
  size_t write_n_;

  bool seek_called_;
  int64 seek_offset_;
  int seek_whence_;

  bool tell_called_;

  bool flush_called_;

  IMPLEMENT_REFCOUNTING(WriteHandlerTester);
};

TEST(StreamTest, WriteHandler) {
  WriteHandlerTester* handler = new WriteHandlerTester();
  ASSERT_TRUE(handler != NULL);

  CefRefPtr<CefStreamWriter> stream(CefStreamWriter::CreateForHandler(handler));
  ASSERT_TRUE(stream.get() != NULL);

  // CefWriteHandler Write
  const char* write_ptr = "My data";
  size_t write_size = sizeof(write_ptr);
  size_t write_n = 1;
  size_t write_res = stream->Write(write_ptr, write_size, write_n);
  ASSERT_TRUE(handler->write_called_);
  ASSERT_EQ((size_t)10, write_res);
  ASSERT_EQ(write_ptr, handler->write_ptr_);
  ASSERT_EQ(write_size, handler->write_size_);
  ASSERT_EQ(write_n, handler->write_n_);

  // CefWriteHandler Seek
  int64 seek_offset = 10;
  int seek_whence = SEEK_CUR;
  int seek_res = stream->Seek(seek_offset, seek_whence);
  ASSERT_TRUE(handler->seek_called_);
  ASSERT_EQ(10, seek_res);
  ASSERT_EQ(seek_offset, handler->seek_offset_);
  ASSERT_EQ(seek_whence, handler->seek_whence_);

  // CefWriteHandler Tell
  int64 tell_res = stream->Tell();
  ASSERT_TRUE(handler->tell_called_);
  ASSERT_EQ(10, tell_res);

  // CefWriteHandler Flush
  int flush_res = stream->Flush();
  ASSERT_TRUE(handler->flush_called_);
  ASSERT_EQ(10, flush_res);

  // Delete the stream
  stream = NULL;

  // Verify that the handler object was deleted
  ASSERT_TRUE(g_WriteHandlerTesterDeleted);
}
