// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "tests/unittests/test_handler.h"
#include "include/cef_command_line.h"
#include "include/cef_runnable.h"
#include "include/cef_stream.h"
#include "include/wrapper/cef_stream_resource_handler.h"

namespace {

void NotifyEvent(base::WaitableEvent* event) {
  event->Signal();
}

}  // namespace


// TestHandler

TestHandler::TestHandler()
  : browser_id_(0),
    completion_event_(true, false) {
}

TestHandler::~TestHandler() {
}

void TestHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  AutoLock lock_scope(this);
  if (!browser->IsPopup()) {
    // Keep the main child window, but not popup windows
    browser_ = browser;
    browser_id_ = browser->GetIdentifier();
  }
}

void TestHandler::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  AutoLock lock_scope(this);
  if (browser_id_ == browser->GetIdentifier()) {
    // Free the browser pointer so that the browser can be destroyed
    browser_ = NULL;
    browser_id_ = 0;

    // Signal that the test is now complete.
    completion_event_.Signal();
  }
}

CefRefPtr<CefResourceHandler> TestHandler::GetResourceHandler(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      CefRefPtr<CefRequest> request) {
  AutoLock lock_scope(this);

  if (resource_map_.size() > 0) {
    CefString url = request->GetURL();

    // Ignore the query component, if any.
    std::string urlStr = url;
    int idx = urlStr.find('?');
    if (idx > 0)
       urlStr = urlStr.substr(0, idx);

    ResourceMap::const_iterator it = resource_map_.find(urlStr);
    if (it != resource_map_.end()) {
      // Return the previously mapped resource
      CefRefPtr<CefStreamReader> stream =
          CefStreamReader::CreateForData(
              static_cast<void*>(const_cast<char*>(it->second.first.c_str())),
              it->second.first.length());
      return new CefStreamResourceHandler(it->second.second, stream);
    }
  }

  return NULL;
}

void TestHandler::ExecuteTest() {
  // Run the test
  RunTest();

  // Wait for the test to complete
  completion_event_.Wait();

  // Reset the event so the same test can be executed again.
  completion_event_.Reset();
}

void TestHandler::DestroyTest() {
  AutoLock lock_scope(this);
  if (browser_id_ != 0)
    browser_->GetHost()->CloseBrowser();
}

void TestHandler::CreateBrowser(const CefString& url) {
  CefWindowInfo windowInfo;
  CefBrowserSettings settings;
#if defined(OS_WIN)
  windowInfo.SetAsPopup(NULL, "CefUnitTest");
  windowInfo.style |= WS_VISIBLE;
#endif
  CefBrowserHost::CreateBrowser(windowInfo, this, url, settings);
}

void TestHandler::AddResource(const std::string& url,
                              const std::string& content,
                              const std::string& mimeType) {
  // Ignore the query component, if any.
  std::string urlStr = url;
  int idx = urlStr.find('?');
  if (idx > 0)
     urlStr = urlStr.substr(0, idx);

  resource_map_.insert(
      std::make_pair(urlStr, std::make_pair(content, mimeType)));
}

void TestHandler::ClearResources() {
  resource_map_.clear();
}


// global functions

void WaitForThread(CefThreadId thread_id) {
  base::WaitableEvent event(true, false);
  CefPostTask(thread_id, NewCefRunnableFunction(&NotifyEvent, &event));
  event.Wait();
}

bool TestFailed() {
  CefRefPtr<CefCommandLine> command_line =
      CefCommandLine::GetGlobalCommandLine();
  if (command_line->HasSwitch("single-process")) {
    // Check for a failure on the current test only.
    return ::testing::UnitTest::GetInstance()->current_test_info()->result()->
        Failed();
  } else {
    // Check for any global failure.
    return ::testing::UnitTest::GetInstance()->Failed();
  }
}
