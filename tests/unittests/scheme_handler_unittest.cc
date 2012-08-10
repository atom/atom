// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_origin_whitelist.h"
#include "include/cef_callback.h"
#include "include/cef_runnable.h"
#include "include/cef_scheme.h"
#include "tests/unittests/test_handler.h"

namespace {

class TestResults {
 public:
  TestResults()
    : status_code(0),
      sub_status_code(0),
      delay(0) {
  }

  void reset() {
    url.clear();
    html.clear();
    status_code = 0;
    redirect_url.clear();
    sub_url.clear();
    sub_html.clear();
    sub_status_code = 0;
    sub_allow_origin.clear();
    exit_url.clear();
    delay = 0;
    got_request.reset();
    got_read.reset();
    got_output.reset();
    got_redirect.reset();
    got_error.reset();
    got_sub_request.reset();
    got_sub_read.reset();
    got_sub_success.reset();
  }

  std::string url;
  std::string html;
  int status_code;

  // Used for testing redirects
  std::string redirect_url;

  // Used for testing XHR requests
  std::string sub_url;
  std::string sub_html;
  int sub_status_code;
  std::string sub_allow_origin;
  std::string exit_url;

  // Delay for returning scheme handler results.
  int delay;

  TrackCallback
      got_request,
      got_read,
      got_output,
      got_redirect,
      got_error,
      got_sub_request,
      got_sub_read,
      got_sub_success;
};

// Current scheme handler object. Used when destroying the test from
// ClientSchemeHandler::ProcessRequest().
class TestSchemeHandler;
TestSchemeHandler* g_current_handler = NULL;

class TestSchemeHandler : public TestHandler {
 public:
  explicit TestSchemeHandler(TestResults* tr)
    : test_results_(tr) {
    g_current_handler = this;
  }

  virtual void RunTest() OVERRIDE {
    CreateBrowser(test_results_->url);
  }

  // Necessary to make the method public in order to destroy the test from
  // ClientSchemeHandler::ProcessRequest().
  void DestroyTest() {
    TestHandler::DestroyTest();
  }

  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request) OVERRIDE {
    std::string newUrl = request->GetURL();
    if (!test_results_->exit_url.empty() &&
        newUrl.find(test_results_->exit_url) != std::string::npos) {
      // XHR tests use an exit URL to destroy the test.
      if (newUrl.find("SUCCESS") != std::string::npos)
        test_results_->got_sub_success.yes();
      DestroyTest();
      return true;
    }

    if (newUrl == test_results_->redirect_url) {
      test_results_->got_redirect.yes();

      // No read should have occurred for the redirect.
      EXPECT_TRUE(test_results_->got_request);
      EXPECT_FALSE(test_results_->got_read);

      // Now loading the redirect URL.
      test_results_->url = test_results_->redirect_url;
      test_results_->redirect_url.clear();
    }

    return false;
  }

  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE {
    std::string url = frame->GetURL();
    if (url == test_results_->url || test_results_->status_code != 200) {
      test_results_->got_output.yes();

      // Test that the status code is correct.
      // TODO(cef): Enable this check once the HTTP status code is passed
      // correctly.
      // EXPECT_EQ(httpStatusCode, test_results_->status_code);

      if (test_results_->sub_url.empty())
        DestroyTest();
    }
  }

  virtual void OnLoadError(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           ErrorCode errorCode,
                           const CefString& errorText,
                           const CefString& failedUrl) OVERRIDE {
    test_results_->got_error.yes();
    DestroyTest();
  }

 protected:
  TestResults* test_results_;
};

class ClientSchemeHandler : public CefResourceHandler {
 public:
  explicit ClientSchemeHandler(TestResults* tr)
    : test_results_(tr),
      offset_(0),
      is_sub_(false),
      has_delayed_(false) {
  }

  virtual bool ProcessRequest(CefRefPtr<CefRequest> request,
                              CefRefPtr<CefCallback> callback) OVERRIDE {
    EXPECT_TRUE(CefCurrentlyOn(TID_IO));

    bool handled = false;

    std::string url = request->GetURL();
    is_sub_ = (!test_results_->sub_url.empty() &&
               test_results_->sub_url == url);

    if (is_sub_) {
      test_results_->got_sub_request.yes();

      if (!test_results_->sub_html.empty())
        handled = true;
    } else {
      EXPECT_EQ(url, test_results_->url);

      test_results_->got_request.yes();

      if (!test_results_->html.empty())
        handled = true;
    }

    if (handled) {
      if (test_results_->delay > 0) {
        // Continue after the delay.
        CefPostDelayedTask(TID_IO,
            NewCefRunnableMethod(callback.get(), &CefCallback::Continue),
            test_results_->delay);
      } else {
        // Continue immediately.
        callback->Continue();
      }
      return true;
    }

    // Response was canceled.
    if (g_current_handler)
      g_current_handler->DestroyTest();
    return false;
  }

  virtual void GetResponseHeaders(CefRefPtr<CefResponse> response,
                                  int64& response_length,
                                  CefString& redirectUrl) OVERRIDE {
    if (is_sub_) {
      response->SetStatus(test_results_->sub_status_code);

      if (!test_results_->sub_allow_origin.empty()) {
        // Set the Access-Control-Allow-Origin header to allow cross-domain
        // scripting.
        CefResponse::HeaderMap headers;
        headers.insert(std::make_pair("Access-Control-Allow-Origin",
                                      test_results_->sub_allow_origin));
        response->SetHeaderMap(headers);
      }

      if (!test_results_->sub_html.empty()) {
        response->SetMimeType("text/html");
        response_length = test_results_->sub_html.size();
      }
    } else if (!test_results_->redirect_url.empty()) {
      redirectUrl = test_results_->redirect_url;
    } else {
      response->SetStatus(test_results_->status_code);

      if (!test_results_->html.empty()) {
        response->SetMimeType("text/html");
        response_length = test_results_->html.size();
      }
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

    if (test_results_->delay > 0) {
      if (!has_delayed_) {
        // Continue after a delay.
        CefPostDelayedTask(TID_IO,
            NewCefRunnableMethod(this,
            &ClientSchemeHandler::ContinueAfterDelay, callback),
            test_results_->delay);
         bytes_read = 0;
         return true;
      }

      has_delayed_ = false;
    }

    std::string* data;

    if (is_sub_) {
      test_results_->got_sub_read.yes();
      data = &test_results_->sub_html;
    } else {
      test_results_->got_read.yes();
      data = &test_results_->html;
    }

    bool has_data = false;
    bytes_read = 0;

    AutoLock lock_scope(this);

    size_t size = data->size();
    if (offset_ < size) {
      int transfer_size =
          std::min(bytes_to_read, static_cast<int>(size - offset_));
      memcpy(data_out, data->c_str() + offset_, transfer_size);
      offset_ += transfer_size;

      bytes_read = transfer_size;
      has_data = true;
    }

    return has_data;
  }

 private:
  void ContinueAfterDelay(CefRefPtr<CefCallback> callback) {
    has_delayed_ = true;
    callback->Continue();
  }

  TestResults* test_results_;
  size_t offset_;
  bool is_sub_;
  bool has_delayed_;

  IMPLEMENT_REFCOUNTING(ClientSchemeHandler);
  IMPLEMENT_LOCKING(ClientSchemeHandler);
};

class ClientSchemeHandlerFactory : public CefSchemeHandlerFactory {
 public:
  explicit ClientSchemeHandlerFactory(TestResults* tr)
    : test_results_(tr) {
  }

  virtual CefRefPtr<CefResourceHandler> Create(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      const CefString& scheme_name,
      CefRefPtr<CefRequest> request)
      OVERRIDE {
    EXPECT_TRUE(CefCurrentlyOn(TID_IO));
    return new ClientSchemeHandler(test_results_);
  }

  TestResults* test_results_;

  IMPLEMENT_REFCOUNTING(ClientSchemeHandlerFactory);
};

// Global test results object.
TestResults g_TestResults;

// If |domain| is empty the scheme will be registered as non-standard.
void RegisterTestScheme(const std::string& scheme, const std::string& domain) {
  g_TestResults.reset();

  EXPECT_TRUE(CefRegisterSchemeHandlerFactory(scheme, domain,
      new ClientSchemeHandlerFactory(&g_TestResults)));
  WaitForIOThread();
}

void ClearTestSchemes() {
  EXPECT_TRUE(CefClearSchemeHandlerFactories());
  WaitForIOThread();
}

void SetUpXHR(const std::string& url, const std::string& sub_url,
              const std::string& sub_allow_origin = std::string()) {
  g_TestResults.sub_url = sub_url;
  g_TestResults.sub_html = "SUCCESS";
  g_TestResults.sub_status_code = 200;
  g_TestResults.sub_allow_origin = sub_allow_origin;

  g_TestResults.url = url;
  std::stringstream ss;
  ss << "<html><head>"
        "<script language=\"JavaScript\">"
        "function execXMLHttpRequest() {"
        "  var result = 'FAILURE';"
        "  try {"
        "    xhr = new XMLHttpRequest();"
        "    xhr.open(\"GET\", \"" << sub_url.c_str() << "\", false);"
        "    xhr.send();"
        "    result = xhr.responseText;"
        "  } catch(e) {}"
        "  document.location = \"http://tests/exit?result=\"+result;"
        "}"
        "</script>"
        "</head><body onload=\"execXMLHttpRequest();\">"
        "Running execXMLHttpRequest..."
        "</body></html>";
  g_TestResults.html = ss.str();
  g_TestResults.status_code = 200;

  g_TestResults.exit_url = "http://tests/exit";
}

void SetUpXSS(const std::string& url, const std::string& sub_url,
              const std::string& domain = std::string()) {
  // 1. Load |url| which contains an iframe.
  // 2. The iframe loads |xss_url|.
  // 3. |xss_url| tries to call a JS function in |url|.
  // 4. |url| tries to call a JS function in |xss_url|.

  std::stringstream ss;
  std::string domain_line;
  if (!domain.empty())
    domain_line = "document.domain = '" + domain + "';";

  g_TestResults.sub_url = sub_url;
  ss << "<html><head>"
        "<script language=\"JavaScript\">" << domain_line <<
        "function getResult() {"
        "  return 'SUCCESS';"
        "}"
        "function execXSSRequest() {"
        "  var result = 'FAILURE';"
        "  try {"
        "    result = parent.getResult();"
        "  } catch(e) {}"
        "  document.location = \"http://tests/exit?result=\"+result;"
        "}"
        "</script>"
        "</head><body onload=\"execXSSRequest();\">"
        "Running execXSSRequest..."
        "</body></html>";
  g_TestResults.sub_html = ss.str();
  g_TestResults.sub_status_code = 200;

  g_TestResults.url = url;
  ss.str("");
  ss << "<html><head>"
        "<script language=\"JavaScript\">" << domain_line << ""
        "function getResult() {"
        "  try {"
        "    return document.getElementById('s').contentWindow.getResult();"
        "  } catch(e) {}"
        "  return 'FAILURE';"
        "}"
        "</script>"
        "</head><body>"
        "<iframe src=\"" << sub_url.c_str() << "\" id=\"s\">"
        "</body></html>";
  g_TestResults.html = ss.str();
  g_TestResults.status_code = 200;

  g_TestResults.exit_url = "http://tests/exit";
}

}  // namespace

// Test that scheme registration/unregistration works as expected.
TEST(SchemeHandlerTest, Registration) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd://test/run.html";
  g_TestResults.html =
      "<html><head></head><body><h1>Success!</h1></body></html>";
  g_TestResults.status_code = 200;

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);

  // Unregister the handler.
  EXPECT_TRUE(CefRegisterSchemeHandlerFactory("customstd", "test", NULL));
  WaitForIOThread();

  g_TestResults.got_request.reset();
  g_TestResults.got_read.reset();
  g_TestResults.got_output.reset();
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_error);
  EXPECT_FALSE(g_TestResults.got_request);
  EXPECT_FALSE(g_TestResults.got_read);
  EXPECT_FALSE(g_TestResults.got_output);

  // Re-register the handler.
  EXPECT_TRUE(CefRegisterSchemeHandlerFactory("customstd", "test",
      new ClientSchemeHandlerFactory(&g_TestResults)));
  WaitForIOThread();

  g_TestResults.got_error.reset();
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom standard scheme can return normal results.
TEST(SchemeHandlerTest, CustomStandardNormalResponse) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd://test/run.html";
  g_TestResults.html =
      "<html><head></head><body><h1>Success!</h1></body></html>";
  g_TestResults.status_code = 200;

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom standard scheme can return normal results with delayed
// responses.
TEST(SchemeHandlerTest, CustomStandardNormalResponseDelayed) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd://test/run.html";
  g_TestResults.html =
      "<html><head></head><body><h1>Success!</h1></body></html>";
  g_TestResults.status_code = 200;
  g_TestResults.delay = 100;

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom nonstandard scheme can return normal results.
TEST(SchemeHandlerTest, CustomNonStandardNormalResponse) {
  RegisterTestScheme("customnonstd", std::string());
  g_TestResults.url = "customnonstd:some%20value";
  g_TestResults.html =
      "<html><head></head><body><h1>Success!</h1></body></html>";
  g_TestResults.status_code = 200;

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom standard scheme can return an error code.
TEST(SchemeHandlerTest, CustomStandardErrorResponse) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd://test/run.html";
  g_TestResults.html =
      "<html><head></head><body><h1>404</h1></body></html>";
  g_TestResults.status_code = 404;

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom nonstandard scheme can return an error code.
TEST(SchemeHandlerTest, CustomNonStandardErrorResponse) {
  RegisterTestScheme("customnonstd", std::string());
  g_TestResults.url = "customnonstd:some%20value";
  g_TestResults.html =
      "<html><head></head><body><h1>404</h1></body></html>";
  g_TestResults.status_code = 404;

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that custom standard scheme handling fails when the scheme name is
// incorrect.
TEST(SchemeHandlerTest, CustomStandardNameNotHandled) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd2://test/run.html";

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_FALSE(g_TestResults.got_request);
  EXPECT_FALSE(g_TestResults.got_read);
  EXPECT_FALSE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that custom nonstandard scheme handling fails when the scheme name is
// incorrect.
TEST(SchemeHandlerTest, CustomNonStandardNameNotHandled) {
  RegisterTestScheme("customnonstd", std::string());
  g_TestResults.url = "customnonstd2:some%20value";

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_FALSE(g_TestResults.got_request);
  EXPECT_FALSE(g_TestResults.got_read);
  EXPECT_FALSE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that custom standard scheme handling fails when the domain name is
// incorrect.
TEST(SchemeHandlerTest, CustomStandardDomainNotHandled) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd://noexist/run.html";

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_FALSE(g_TestResults.got_request);
  EXPECT_FALSE(g_TestResults.got_read);
  EXPECT_FALSE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom standard scheme can return no response.
TEST(SchemeHandlerTest, CustomStandardNoResponse) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd://test/run.html";

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_FALSE(g_TestResults.got_read);
  EXPECT_FALSE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom nonstandard scheme can return no response.
TEST(SchemeHandlerTest, CustomNonStandardNoResponse) {
  RegisterTestScheme("customnonstd", std::string());
  g_TestResults.url = "customnonstd:some%20value";

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_FALSE(g_TestResults.got_read);
  EXPECT_FALSE(g_TestResults.got_output);

  ClearTestSchemes();
}

// Test that a custom standard scheme can generate redirects.
TEST(SchemeHandlerTest, CustomStandardRedirect) {
  RegisterTestScheme("customstd", "test");
  g_TestResults.url = "customstd://test/run.html";
  g_TestResults.redirect_url = "customstd://test/redirect.html";
  g_TestResults.html =
      "<html><head></head><body><h1>Redirected</h1></body></html>";

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_redirect);

  ClearTestSchemes();
}

// Test that a custom nonstandard scheme can generate redirects.
TEST(SchemeHandlerTest, CustomNonStandardRedirect) {
  RegisterTestScheme("customnonstd", std::string());
  g_TestResults.url = "customnonstd:some%20value";
  g_TestResults.redirect_url = "customnonstd:some%20other%20value";
  g_TestResults.html =
      "<html><head></head><body><h1>Redirected</h1></body></html>";

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_redirect);

  ClearTestSchemes();
}

// Test that a custom standard scheme can generate same origin XHR requests.
TEST(SchemeHandlerTest, CustomStandardXHRSameOrigin) {
  RegisterTestScheme("customstd", "test");
  SetUpXHR("customstd://test/run.html",
           "customstd://test/xhr.html");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that a custom nonstandard scheme can generate same origin XHR requests.
TEST(SchemeHandlerTest, CustomNonStandardXHRSameOrigin) {
  RegisterTestScheme("customnonstd", std::string());
  SetUpXHR("customnonstd:some%20value",
           "customnonstd:xhr%20value");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}
// Test that a custom standard scheme can generate same origin XSS requests.
TEST(SchemeHandlerTest, CustomStandardXSSSameOrigin) {
  RegisterTestScheme("customstd", "test");
  SetUpXSS("customstd://test/run.html",
           "customstd://test/iframe.html");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that a custom nonstandard scheme can generate same origin XSS requests.
TEST(SchemeHandlerTest, CustomNonStandardXSSSameOrigin) {
  RegisterTestScheme("customnonstd", std::string());
  SetUpXSS("customnonstd:some%20value",
           "customnonstd:xhr%20value");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that a custom standard scheme cannot generate cross-domain XHR requests
// by default.
TEST(SchemeHandlerTest, CustomStandardXHRDifferentOrigin) {
  RegisterTestScheme("customstd", "test1");
  RegisterTestScheme("customstd", "test2");
  SetUpXHR("customstd://test1/run.html",
           "customstd://test2/xhr.html");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_FALSE(g_TestResults.got_sub_request);
  EXPECT_FALSE(g_TestResults.got_sub_read);
  EXPECT_FALSE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that a custom standard scheme cannot generate cross-domain XSS requests
// by default.
TEST(SchemeHandlerTest, CustomStandardXSSDifferentOrigin) {
  RegisterTestScheme("customstd", "test1");
  RegisterTestScheme("customstd", "test2");
  SetUpXSS("customstd://test1/run.html",
           "customstd://test2/iframe.html");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_FALSE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that an HTTP scheme cannot generate cross-domain XHR requests by
// default.
TEST(SchemeHandlerTest, HttpXHRDifferentOrigin) {
  RegisterTestScheme("http", "test1");
  RegisterTestScheme("http", "test2");
  SetUpXHR("http://test1/run.html",
           "http://test2/xhr.html");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_FALSE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that an HTTP scheme cannot generate cross-domain XSS requests by
// default.
TEST(SchemeHandlerTest, HttpXSSDifferentOrigin) {
  RegisterTestScheme("http", "test1");
  RegisterTestScheme("http", "test2");
  SetUpXHR("http://test1/run.html",
           "http://test2/xhr.html");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_FALSE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that a custom standard scheme cannot generate cross-domain XHR requests
// even when setting the Access-Control-Allow-Origin header.
TEST(SchemeHandlerTest, CustomStandardXHRDifferentOriginWithHeader) {
  RegisterTestScheme("customstd", "test1");
  RegisterTestScheme("customstd", "test2");
  SetUpXHR("customstd://test1/run.html",
           "customstd://test2/xhr.html",
           "customstd://test1");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_FALSE(g_TestResults.got_sub_request);
  EXPECT_FALSE(g_TestResults.got_sub_read);
  EXPECT_FALSE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that a custom standard scheme can generate cross-domain XHR requests
// when using the cross-origin whitelist.
TEST(SchemeHandlerTest, CustomStandardXHRDifferentOriginWithWhitelist) {
  RegisterTestScheme("customstd", "test1");
  RegisterTestScheme("customstd", "test2");
  SetUpXHR("customstd://test1/run.html",
           "customstd://test2/xhr.html");

  EXPECT_TRUE(CefAddCrossOriginWhitelistEntry("customstd://test1", "customstd",
      "test2", false));
  WaitForUIThread();

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  EXPECT_TRUE(CefClearCrossOriginWhitelist());
  WaitForUIThread();

  ClearTestSchemes();
}

// Test that an HTTP scheme can generate cross-domain XHR requests when setting
// the Access-Control-Allow-Origin header.
TEST(SchemeHandlerTest, HttpXHRDifferentOriginWithHeader) {
  RegisterTestScheme("http", "test1");
  RegisterTestScheme("http", "test2");
  SetUpXHR("http://test1/run.html",
           "http://test2/xhr.html",
           "http://test1");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that a custom standard scheme can generate cross-domain XSS requests
// when using document.domain.
TEST(SchemeHandlerTest, CustomStandardXSSDifferentOriginWithDomain) {
  RegisterTestScheme("customstd", "a.test");
  RegisterTestScheme("customstd", "b.test");
  SetUpXSS("customstd://a.test/run.html",
           "customstd://b.test/iframe.html",
           "test");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Test that an HTTP scheme can generate cross-domain XSS requests when using
// document.domain.
TEST(SchemeHandlerTest, HttpXSSDifferentOriginWithDomain) {
  RegisterTestScheme("http", "a.test");
  RegisterTestScheme("http", "b.test");
  SetUpXSS("http://a.test/run.html",
           "http://b.test/iframe.html",
           "test");

  CefRefPtr<TestSchemeHandler> handler = new TestSchemeHandler(&g_TestResults);
  handler->ExecuteTest();

  EXPECT_TRUE(g_TestResults.got_request);
  EXPECT_TRUE(g_TestResults.got_read);
  EXPECT_TRUE(g_TestResults.got_output);
  EXPECT_TRUE(g_TestResults.got_sub_request);
  EXPECT_TRUE(g_TestResults.got_sub_read);
  EXPECT_TRUE(g_TestResults.got_sub_success);

  ClearTestSchemes();
}

// Entry point for registering custom schemes.
// Called from client_app_delegates.cc.
void RegisterSchemeHandlerCustomSchemes(
      CefRefPtr<CefSchemeRegistrar> registrar,
      std::vector<CefString>& cookiable_schemes) {
  // Add a custom standard scheme.
  registrar->AddCustomScheme("customstd", true, false, false);
  // Ad a custom non-standard scheme.
  registrar->AddCustomScheme("customnonstd", false, false, false);
}
