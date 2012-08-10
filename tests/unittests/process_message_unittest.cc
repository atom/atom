// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_process_message.h"
#include "include/cef_task.h"
#include "tests/cefclient/client_app.h"
#include "tests/unittests/test_handler.h"
#include "tests/unittests/test_util.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace {

// Unique values for the SendRecv test.
const char* kSendRecvUrlNative =
    "http://tests/ProcessMessageTest.SendRecv/Native";
const char* kSendRecvUrlJavaScript =
    "http://tests/ProcessMessageTest.SendRecv/JavaScript";
const char* kSendRecvMsg = "ProcessMessageTest.SendRecv";

// Creates a test message.
CefRefPtr<CefProcessMessage> CreateTestMessage() {
  CefRefPtr<CefProcessMessage> msg = CefProcessMessage::Create(kSendRecvMsg);
  EXPECT_TRUE(msg.get());

  CefRefPtr<CefListValue> args = msg->GetArgumentList();
  EXPECT_TRUE(args.get());

  int index = 0;
  args->SetNull(index++);
  args->SetInt(index++, 5);
  args->SetDouble(index++, 10.543);
  args->SetBool(index++, true);
  args->SetString(index++, "test string");
  args->SetList(index++, args->Copy());

  EXPECT_EQ((size_t)index, args->GetSize());

  return msg;
}

// Renderer side.
class SendRecvRendererTest : public ClientApp::RenderDelegate {
 public:
  SendRecvRendererTest() {}

  virtual bool OnProcessMessageReceived(
      CefRefPtr<ClientApp> app,
      CefRefPtr<CefBrowser> browser,
      CefProcessId source_process,
      CefRefPtr<CefProcessMessage> message) OVERRIDE {
    if (message->GetName() == kSendRecvMsg) {
      EXPECT_TRUE(browser.get());
      EXPECT_EQ(PID_BROWSER, source_process);
      EXPECT_TRUE(message.get());

      std::string url = browser->GetMainFrame()->GetURL();
      if (url == kSendRecvUrlNative) {
        // Echo the message back to the sender natively.
        EXPECT_TRUE(browser->SendProcessMessage(PID_BROWSER, message));
        return true;
      }
    }

    // Message not handled.
    return false;
  }

  IMPLEMENT_REFCOUNTING(SendRecvRendererTest);
};

// Browser side.
class SendRecvTestHandler : public TestHandler {
 public:
  explicit SendRecvTestHandler(bool native)
    : native_(native) {
  }

  virtual void RunTest() OVERRIDE {
    message_ = CreateTestMessage();

    if (native_) {
      // Native test.
      AddResource(kSendRecvUrlNative, "<html><body>TEST NATIVE</body></html>",
          "text/html");
      CreateBrowser(kSendRecvUrlNative);
    } else {
      // JavaScript test.
      std::string content =
          "<html><head>\n"
          "<script>\n"
          "function cb(name, args) {\n"
          "  app.sendMessage(name, args);\n"
          "}\n"
          "app.setMessageCallback('"+std::string(kSendRecvMsg)+"', cb);\n"
          "</script>\n"
          "<body>TEST JAVASCRIPT</body>\n"
          "</head></html>";
      AddResource(kSendRecvUrlJavaScript, content, "text/html");
      CreateBrowser(kSendRecvUrlJavaScript);
    }
  }

  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE {
    // Send the message to the renderer process.
    EXPECT_TRUE(browser->SendProcessMessage(PID_RENDERER, message_));
  }

  virtual bool OnProcessMessageReceived(
      CefRefPtr<CefBrowser> browser,
      CefProcessId source_process,
      CefRefPtr<CefProcessMessage> message) OVERRIDE {
    EXPECT_TRUE(browser.get());
    EXPECT_EQ(PID_RENDERER, source_process);
    EXPECT_TRUE(message.get());
    EXPECT_TRUE(message->IsReadOnly());
    
    // Verify that the recieved message is the same as the sent message.
    TestProcessMessageEqual(message_, message);

    got_message_.yes();

    // Test is complete.
    DestroyTest();

    return true;
  }

  bool native_;
  CefRefPtr<CefProcessMessage> message_;
  TrackCallback got_message_;
};

}  // namespace

// Verify native send and recieve
TEST(ProcessMessageTest, SendRecvNative) {
  CefRefPtr<SendRecvTestHandler> handler = new SendRecvTestHandler(true);
  handler->ExecuteTest();

  EXPECT_TRUE(handler->got_message_);
}

// Verify JavaScript send and recieve
TEST(ProcessMessageTest, SendRecvJavaScript) {
  CefRefPtr<SendRecvTestHandler> handler = new SendRecvTestHandler(false);
  handler->ExecuteTest();

  EXPECT_TRUE(handler->got_message_);
}

// Verify create
TEST(ProcessMessageTest, Create) {
  CefRefPtr<CefProcessMessage> message =
      CefProcessMessage::Create(kSendRecvMsg);
  EXPECT_TRUE(message.get());
  EXPECT_TRUE(message->IsValid());
  EXPECT_FALSE(message->IsReadOnly());
  EXPECT_STREQ(kSendRecvMsg, message->GetName().ToString().c_str());

  CefRefPtr<CefListValue> args = message->GetArgumentList();
  EXPECT_TRUE(args.get());
  EXPECT_TRUE(args->IsValid());
  EXPECT_TRUE(args->IsOwned());
  EXPECT_FALSE(args->IsReadOnly());
}

// Verify copy
TEST(ProcessMessageTest, Copy) {
  CefRefPtr<CefProcessMessage> message = CreateTestMessage();
  CefRefPtr<CefProcessMessage> message2 = message->Copy();
  TestProcessMessageEqual(message, message2);
}


// Entry point for creating process message renderer test objects.
// Called from client_app_delegates.cc.
void CreateProcessMessageRendererTests(
    ClientApp::RenderDelegateSet& delegates) {
  // For ProcessMessageTest.SendRecv
  delegates.insert(new SendRecvRendererTest);
}
