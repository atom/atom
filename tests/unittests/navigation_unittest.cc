// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_callback.h"
#include "include/cef_scheme.h"
#include "tests/unittests/test_handler.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace {

static const char* kNav1 = "http://tests/nav1.html";
static const char* kNav2 = "http://tests/nav2.html";
static const char* kNav3 = "http://tests/nav3.html";
static const char* kNav4 = "http://tests/nav4.html";

enum NavAction {
  NA_LOAD = 1,
  NA_BACK,
  NA_FORWARD,
  NA_CLEAR
};

typedef struct {
  NavAction action;     // What to do
  const char* target;   // Where to be after navigation
  bool can_go_back;     // After navigation, can go back?
  bool can_go_forward;  // After navigation, can go forward?
} NavListItem;

// Array of navigation actions: X = current page, . = history exists
static NavListItem kNavList[] = {
                                     // kNav1 | kNav2 | kNav3
  {NA_LOAD, kNav1, false, false},    //   X
  {NA_LOAD, kNav2, true, false},     //   .       X
  {NA_BACK, kNav1, false, true},     //   X       .
  {NA_FORWARD, kNav2, true, false},  //   .       X
  {NA_LOAD, kNav3, true, false},     //   .       .       X
  {NA_BACK, kNav2, true, true},      //   .       X       .
  // TODO(cef): Enable once ClearHistory is implemented
  // {NA_CLEAR, kNav2, false, false},   //           X
};

#define NAV_LIST_SIZE() (sizeof(kNavList) / sizeof(NavListItem))

class HistoryNavTestHandler : public TestHandler {
 public:
  HistoryNavTestHandler() : nav_(0) {}

  virtual void RunTest() OVERRIDE {
    // Add the resources that we will navigate to/from.
    AddResource(kNav1, "<html>Nav1</html>", "text/html");
    AddResource(kNav2, "<html>Nav2</html>", "text/html");
    AddResource(kNav3, "<html>Nav3</html>", "text/html");

    // Create the browser.
    CreateBrowser(CefString());
  }

  void RunNav(CefRefPtr<CefBrowser> browser) {
    if (nav_ == NAV_LIST_SIZE()) {
      // End of the nav list.
      DestroyTest();
      return;
    }

    const NavListItem& item = kNavList[nav_];

    // Perform the action.
    switch (item.action) {
    case NA_LOAD:
      browser->GetMainFrame()->LoadURL(item.target);
      break;
    case NA_BACK:
      browser->GoBack();
      break;
    case NA_FORWARD:
      browser->GoForward();
      break;
    case NA_CLEAR:
      // TODO(cef): Enable once ClearHistory is implemented
      // browser->GetHost()->ClearHistory();
      // Not really a navigation action so go to the next one.
      nav_++;
      RunNav(browser);
      break;
    default:
      break;
    }
  }

  virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) OVERRIDE {
    TestHandler::OnAfterCreated(browser);

    RunNav(browser);
  }

  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request) OVERRIDE {
    const NavListItem& item = kNavList[nav_];

    got_before_resource_load_[nav_].yes();

    std::string url = request->GetURL();
    if (url == item.target)
      got_correct_target_[nav_].yes();

    return false;
  }

  virtual void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                    bool isLoading,
                                    bool canGoBack,
                                    bool canGoForward) OVERRIDE {
    const NavListItem& item = kNavList[nav_];

    got_loading_state_change_[nav_].yes();

    if (item.can_go_back == canGoBack)
      got_correct_can_go_back_[nav_].yes();
    if (item.can_go_forward == canGoForward)
      got_correct_can_go_forward_[nav_].yes();
  }

  virtual void OnLoadStart(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame) OVERRIDE {
    if(browser->IsPopup() || !frame->IsMain())
      return;

    const NavListItem& item = kNavList[nav_];

    got_load_start_[nav_].yes();

    std::string url1 = browser->GetMainFrame()->GetURL();
    std::string url2 = frame->GetURL();
    if (url1 == item.target && url2 == item.target)
      got_correct_load_start_url_[nav_].yes();
  }

  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE {
    if (browser->IsPopup() || !frame->IsMain())
      return;

    const NavListItem& item = kNavList[nav_];

    got_load_end_[nav_].yes();

    std::string url1 = browser->GetMainFrame()->GetURL();
    std::string url2 = frame->GetURL();
    if (url1 == item.target && url2 == item.target)
      got_correct_load_end_url_[nav_].yes();

    if (item.can_go_back == browser->CanGoBack())
      got_correct_can_go_back2_[nav_].yes();
    if (item.can_go_forward == browser->CanGoForward())
      got_correct_can_go_forward2_[nav_].yes();

    nav_++;
    RunNav(browser);
  }

  int nav_;

  TrackCallback got_before_resource_load_[NAV_LIST_SIZE()];
  TrackCallback got_correct_target_[NAV_LIST_SIZE()];
  TrackCallback got_loading_state_change_[NAV_LIST_SIZE()];
  TrackCallback got_correct_can_go_back_[NAV_LIST_SIZE()];
  TrackCallback got_correct_can_go_forward_[NAV_LIST_SIZE()];
  TrackCallback got_load_start_[NAV_LIST_SIZE()];
  TrackCallback got_correct_load_start_url_[NAV_LIST_SIZE()];
  TrackCallback got_load_end_[NAV_LIST_SIZE()];
  TrackCallback got_correct_load_end_url_[NAV_LIST_SIZE()];
  TrackCallback got_correct_can_go_back2_[NAV_LIST_SIZE()];
  TrackCallback got_correct_can_go_forward2_[NAV_LIST_SIZE()];
};

}  // namespace

// Verify history navigation.
TEST(NavigationTest, History) {
  CefRefPtr<HistoryNavTestHandler> handler =
      new HistoryNavTestHandler();
  handler->ExecuteTest();

  for (size_t i = 0; i < NAV_LIST_SIZE(); ++i) {
    if (kNavList[i].action != NA_CLEAR) {
      ASSERT_TRUE(handler->got_before_resource_load_[i]) << "i = " << i;
      ASSERT_TRUE(handler->got_correct_target_[i]) << "i = " << i;
      ASSERT_TRUE(handler->got_load_start_[i]) << "i = " << i;
      ASSERT_TRUE(handler->got_correct_load_start_url_[i]) << "i = " << i;
    }

    ASSERT_TRUE(handler->got_loading_state_change_[i]) << "i = " << i;
    ASSERT_TRUE(handler->got_correct_can_go_back_[i]) << "i = " << i;
    ASSERT_TRUE(handler->got_correct_can_go_forward_[i]) << "i = " << i;

    if (kNavList[i].action != NA_CLEAR) {
      ASSERT_TRUE(handler->got_load_end_[i]) << "i = " << i;
      ASSERT_TRUE(handler->got_correct_load_end_url_[i]) << "i = " << i;
      ASSERT_TRUE(handler->got_correct_can_go_back2_[i]) << "i = " << i;
      ASSERT_TRUE(handler->got_correct_can_go_forward2_[i]) << "i = " << i;
    }
  }
}


namespace {

class FrameNameIdentNavTestHandler : public TestHandler {
 public:
  FrameNameIdentNavTestHandler() : browse_ct_(0) {}

  virtual void RunTest() OVERRIDE {
    // Add the frame resources.
    std::stringstream ss;

    // Page with named frame
    ss << "<html>Nav1<iframe src=\"" << kNav2 << "\" name=\"nav2\"></html>";
    AddResource(kNav1, ss.str(), "text/html");
    ss.str("");

    // Page with unnamed frame
    ss << "<html>Nav2<iframe src=\"" << kNav3 << "\"></html>";
    AddResource(kNav2, ss.str(), "text/html");
    ss.str("");

    AddResource(kNav3, "<html>Nav3</html>", "text/html");

    // Create the browser.
    CreateBrowser(kNav1);
  }

  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request) OVERRIDE {
    std::string name = frame->GetName();
    CefRefPtr<CefFrame> parent = frame->GetParent();

    std::string url = request->GetURL();
    if (url == kNav1) {
      frame1_ident_ = frame->GetIdentifier();
      if (name == "") {
        frame1_name_ = name;
        got_frame1_name_.yes();
      }
      if (!parent.get())
        got_frame1_ident_parent_before_.yes();
    } else if (url == kNav2) {
      frame2_ident_ = frame->GetIdentifier();
      if (name == "nav2") {
        frame2_name_ = name;
        got_frame2_name_.yes();
      }
      if (parent.get() && frame1_ident_ == parent->GetIdentifier())
        got_frame2_ident_parent_before_.yes();
    } else if (url == kNav3) {
      frame3_ident_ = frame->GetIdentifier();
      if (name == "<!--framePath //nav2/<!--frame0-->-->") {
        frame3_name_ = name;
        got_frame3_name_.yes();
      }
       if (parent.get() && frame2_ident_ == parent->GetIdentifier())
        got_frame3_ident_parent_before_.yes();
    }

    return false;
  }

  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE {
    std::string url = frame->GetURL();
    CefRefPtr<CefFrame> parent = frame->GetParent();

    if (url == kNav1) {
      if (frame1_ident_ == frame->GetIdentifier())
        got_frame1_ident_.yes();
      if (!parent.get())
        got_frame1_ident_parent_after_.yes();
    } else if (url == kNav2) {
      if (frame2_ident_ == frame->GetIdentifier())
        got_frame2_ident_.yes();
      if (parent.get() && frame1_ident_ == parent->GetIdentifier())
        got_frame2_ident_parent_after_.yes();
    } else if (url == kNav3) {
      if (frame3_ident_ == frame->GetIdentifier())
        got_frame3_ident_.yes();
      if (parent.get() && frame2_ident_ == parent->GetIdentifier())
        got_frame3_ident_parent_after_.yes();
    }

    if (++browse_ct_ == 3) {
      // Test GetFrameNames
      std::vector<CefString> names;
      browser->GetFrameNames(names);
      EXPECT_EQ((size_t)3, names.size());
      EXPECT_STREQ(frame1_name_.c_str(), names[0].ToString().c_str());
      EXPECT_STREQ(frame2_name_.c_str(), names[1].ToString().c_str());
      EXPECT_STREQ(frame3_name_.c_str(), names[2].ToString().c_str());

      // Test GetFrameIdentifiers
      std::vector<int64> idents;
      browser->GetFrameIdentifiers(idents);
      EXPECT_EQ((size_t)3, idents.size());
      EXPECT_EQ(frame1_ident_, idents[0]);
      EXPECT_EQ(frame2_ident_, idents[1]);
      EXPECT_EQ(frame3_ident_, idents[2]);

      DestroyTest();
    }
  }

  int browse_ct_;

  int64 frame1_ident_;
  std::string frame1_name_;
  int64 frame2_ident_;
  std::string frame2_name_;
  int64 frame3_ident_;
  std::string frame3_name_;

  TrackCallback got_frame1_name_;
  TrackCallback got_frame2_name_;
  TrackCallback got_frame3_name_;
  TrackCallback got_frame1_ident_;
  TrackCallback got_frame2_ident_;
  TrackCallback got_frame3_ident_;
  TrackCallback got_frame1_ident_parent_before_;
  TrackCallback got_frame2_ident_parent_before_;
  TrackCallback got_frame3_ident_parent_before_;
  TrackCallback got_frame1_ident_parent_after_;
  TrackCallback got_frame2_ident_parent_after_;
  TrackCallback got_frame3_ident_parent_after_;
};

}  // namespace

// Verify frame names and identifiers.
TEST(NavigationTest, FrameNameIdent) {
  CefRefPtr<FrameNameIdentNavTestHandler> handler =
      new FrameNameIdentNavTestHandler();
  handler->ExecuteTest();

  ASSERT_GT(handler->frame1_ident_, 0);
  ASSERT_GT(handler->frame2_ident_, 0);
  ASSERT_GT(handler->frame3_ident_, 0);
  ASSERT_TRUE(handler->got_frame1_name_);
  ASSERT_TRUE(handler->got_frame2_name_);
  ASSERT_TRUE(handler->got_frame3_name_);
  ASSERT_TRUE(handler->got_frame1_ident_);
  ASSERT_TRUE(handler->got_frame2_ident_);
  ASSERT_TRUE(handler->got_frame3_ident_);
  ASSERT_TRUE(handler->got_frame1_ident_parent_before_);
  ASSERT_TRUE(handler->got_frame2_ident_parent_before_);
  ASSERT_TRUE(handler->got_frame3_ident_parent_before_);
  ASSERT_TRUE(handler->got_frame1_ident_parent_after_);
  ASSERT_TRUE(handler->got_frame2_ident_parent_after_);
  ASSERT_TRUE(handler->got_frame3_ident_parent_after_);
}


namespace {

bool g_got_nav1_request = false;
bool g_got_nav3_request = false;
bool g_got_nav4_request = false;
bool g_got_invalid_request = false;

class RedirectSchemeHandler : public CefResourceHandler {
 public:
  RedirectSchemeHandler() : offset_(0), status_(0) {}

  virtual bool ProcessRequest(CefRefPtr<CefRequest> request,
                              CefRefPtr<CefCallback> callback) OVERRIDE {
    EXPECT_TRUE(CefCurrentlyOn(TID_IO));

    std::string url = request->GetURL();
    if (url == kNav1) {
      // Redirect using HTTP 302
      g_got_nav1_request = true;
      status_ = 302;
      location_ = kNav2;
      content_ = "<html><body>Redirected Nav1</body></html>";
    } else if (url == kNav3) {
      // Redirect using redirectUrl
      g_got_nav3_request = true;
      status_ = -1;
      location_ = kNav4;
      content_ = "<html><body>Redirected Nav3</body></html>";
    } else if (url == kNav4) {
      g_got_nav4_request = true;
      status_ = 200;
      content_ = "<html><body>Nav4</body></html>";
    }

    if (status_ != 0) {
      callback->Continue();
      return true;
    } else {
      g_got_invalid_request = true;
      return false;
    }
  }

  virtual void GetResponseHeaders(CefRefPtr<CefResponse> response,
                                  int64& response_length,
                                  CefString& redirectUrl) OVERRIDE {
    EXPECT_TRUE(CefCurrentlyOn(TID_IO));

    EXPECT_NE(status_, 0);

    response->SetStatus(status_);
    response->SetMimeType("text/html");
    response_length = content_.size();

    if (status_ == 302) {
      // Redirect using HTTP 302
      EXPECT_GT(location_.size(), static_cast<size_t>(0));
      response->SetStatusText("Found");
      CefResponse::HeaderMap headers;
      response->GetHeaderMap(headers);
      headers.insert(std::make_pair("Location", location_));
      response->SetHeaderMap(headers);
    } else if (status_ == -1) {
      // Rdirect using redirectUrl
      EXPECT_GT(location_.size(), static_cast<size_t>(0));
      redirectUrl = location_;
    }
  }

  virtual void Cancel() OVERRIDE {
    EXPECT_TRUE(CefCurrentlyOn(TID_IO));
  }

  virtual bool ReadResponse(void* data_out,
                            int bytes_to_read,
                            int& bytes_read,
                            CefRefPtr<CefCallback> callback) OVERRIDE {
    EXPECT_TRUE(CefCurrentlyOn(TID_IO));

    size_t size = content_.size();
    if (offset_ < size) {
      int transfer_size =
          std::min(bytes_to_read, static_cast<int>(size - offset_));
      memcpy(data_out, content_.c_str() + offset_, transfer_size);
      offset_ += transfer_size;

      bytes_read = transfer_size;
      return true;
    }

    return false;
  }

 protected:
  std::string content_;
  size_t offset_;
  int status_;
  std::string location_;

  IMPLEMENT_REFCOUNTING(RedirectSchemeHandler);
};

class RedirectSchemeHandlerFactory : public CefSchemeHandlerFactory {
 public:
  RedirectSchemeHandlerFactory() {}

  virtual CefRefPtr<CefResourceHandler> Create(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      const CefString& scheme_name,
      CefRefPtr<CefRequest> request) OVERRIDE {
    EXPECT_TRUE(CefCurrentlyOn(TID_IO));
    return new RedirectSchemeHandler();
  }

  IMPLEMENT_REFCOUNTING(RedirectSchemeHandlerFactory);
};

class RedirectTestHandler : public TestHandler {
 public:
  RedirectTestHandler() {}

  virtual void RunTest() OVERRIDE {
    // Create the browser.
    CreateBrowser(kNav1);
  }

  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request) OVERRIDE {
    // Should be called for all but the second URL.
    std::string url = request->GetURL();

    if (url == kNav1) {
      got_nav1_before_resource_load_.yes();
    } else if (url == kNav3) {
      got_nav3_before_resource_load_.yes();
    } else if (url == kNav4) {
      got_nav4_before_resource_load_.yes();
    } else {
      got_invalid_before_resource_load_.yes();
    }

    return false;
  }

  virtual void OnResourceRedirect(CefRefPtr<CefBrowser> browser,
                                  CefRefPtr<CefFrame> frame,
                                  const CefString& old_url,
                                  CefString& new_url) OVERRIDE {
    // Should be called for each redirected URL.

    if (old_url == kNav1 && new_url == kNav2) {
      // Called due to the nav1 redirect response.
      got_nav1_redirect_.yes();

      // Change the redirect to the 3rd URL.
      new_url = kNav3;
    } else if (old_url == kNav1 && new_url == kNav3) {
      // Called due to the redirect change above.
      got_nav2_redirect_.yes();
    } else if (old_url == kNav3 && new_url == kNav4) {
      // Called due to the nav3 redirect response.
      got_nav3_redirect_.yes();
    } else {
      got_invalid_redirect_.yes();
    }
  }

  virtual void OnLoadStart(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame) OVERRIDE {
    // Should only be called for the final loaded URL.
    std::string url = frame->GetURL();

    if (url == kNav4) {
      got_nav4_load_start_.yes();
    } else {
      got_invalid_load_start_.yes();
    }
  }

  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE {
    // Should only be called for the final loaded URL.
    std::string url = frame->GetURL();

    if (url == kNav4) {
      got_nav4_load_end_.yes();
      DestroyTest();
    } else {
      got_invalid_load_end_.yes();
    }
  }

  TrackCallback got_nav1_before_resource_load_;
  TrackCallback got_nav3_before_resource_load_;
  TrackCallback got_nav4_before_resource_load_;
  TrackCallback got_invalid_before_resource_load_;
  TrackCallback got_nav4_load_start_;
  TrackCallback got_invalid_load_start_;
  TrackCallback got_nav4_load_end_;
  TrackCallback got_invalid_load_end_;
  TrackCallback got_nav1_redirect_;
  TrackCallback got_nav2_redirect_;
  TrackCallback got_nav3_redirect_;
  TrackCallback got_invalid_redirect_;
};

}  // namespace

// Verify frame names and identifiers.
TEST(NavigationTest, Redirect) {
  CefRegisterSchemeHandlerFactory("http", "tests",
      new RedirectSchemeHandlerFactory());
  WaitForIOThread();

  CefRefPtr<RedirectTestHandler> handler =
      new RedirectTestHandler();
  handler->ExecuteTest();

  CefClearSchemeHandlerFactories();
  WaitForIOThread();

  ASSERT_TRUE(handler->got_nav1_before_resource_load_);
  ASSERT_TRUE(handler->got_nav3_before_resource_load_);
  ASSERT_TRUE(handler->got_nav4_before_resource_load_);
  ASSERT_FALSE(handler->got_invalid_before_resource_load_);
  ASSERT_TRUE(handler->got_nav4_load_start_);
  ASSERT_FALSE(handler->got_invalid_load_start_);
  ASSERT_TRUE(handler->got_nav4_load_end_);
  ASSERT_FALSE(handler->got_invalid_load_end_);
  ASSERT_TRUE(handler->got_nav1_redirect_);
  ASSERT_TRUE(handler->got_nav2_redirect_);
  ASSERT_TRUE(handler->got_nav3_redirect_);
  ASSERT_FALSE(handler->got_invalid_redirect_);
  ASSERT_TRUE(g_got_nav1_request);
  ASSERT_TRUE(g_got_nav3_request);
  ASSERT_TRUE(g_got_nav4_request);
  ASSERT_FALSE(g_got_invalid_request);
}
