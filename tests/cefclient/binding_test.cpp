// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "cefclient/binding_test.h"

#include <algorithm>
#include <string>

#include "include/wrapper/cef_stream_resource_handler.h"
#include "cefclient/resource_util.h"

namespace binding_test {

namespace {

const char* kTestUrl = "http://tests/binding";
const char* kMessageName = "binding_test";

// Handle messages in the browser process.
class ProcessMessageDelegate : public ClientHandler::ProcessMessageDelegate {
 public:
  ProcessMessageDelegate() {
  }

  // From ClientHandler::ProcessMessageDelegate.
  virtual bool OnProcessMessageReceived(
      CefRefPtr<ClientHandler> handler,
      CefRefPtr<CefBrowser> browser,
      CefProcessId source_process,
      CefRefPtr<CefProcessMessage> message) OVERRIDE {
    std::string message_name = message->GetName();
    if (message_name == kMessageName) {
      // Handle the message.
      std::string result;

      CefRefPtr<CefListValue> args = message->GetArgumentList();
      if (args->GetSize() > 0 && args->GetType(0) == VTYPE_STRING) {
        // Our result is a reverse of the original message.
        result = args->GetString(0);
        std::reverse(result.begin(), result.end());
      } else {
        result = "Invalid request";
      }

      // Send the result back to the render process.
      CefRefPtr<CefProcessMessage> response =
          CefProcessMessage::Create(kMessageName);
      response->GetArgumentList()->SetString(0, result);
      browser->SendProcessMessage(PID_RENDERER, response);

      return true;
    }

    return false;
  }

  IMPLEMENT_REFCOUNTING(ProcessMessageDelegate);
};

// Handle resource loading in the browser process.
class RequestDelegate: public ClientHandler::RequestDelegate {
 public:
  RequestDelegate() {
  }

  // From ClientHandler::RequestDelegate.
  virtual CefRefPtr<CefResourceHandler> GetResourceHandler(
      CefRefPtr<ClientHandler> handler,
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      CefRefPtr<CefRequest> request) OVERRIDE {
    std::string url = request->GetURL();
    if (url == kTestUrl) {
      // Show the binding contents
      CefRefPtr<CefStreamReader> stream =
          GetBinaryResourceReader("binding.html");
      ASSERT(stream.get());
      return new CefStreamResourceHandler("text/html", stream);
    }

    return NULL;
  }

  IMPLEMENT_REFCOUNTING(RequestDelegate);
};

}  // namespace

void CreateProcessMessageDelegates(
    ClientHandler::ProcessMessageDelegateSet& delegates) {
  delegates.insert(new ProcessMessageDelegate);
}

void CreateRequestDelegates(ClientHandler::RequestDelegateSet& delegates) {
  delegates.insert(new RequestDelegate);
}

void RunTest(CefRefPtr<CefBrowser> browser) {
  // Load the test URL.
  browser->GetMainFrame()->LoadURL(kTestUrl);
}

}  // namespace binding_test
