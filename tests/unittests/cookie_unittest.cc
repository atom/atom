// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <vector>
#include "include/cef_cookie.h"
#include "include/cef_runnable.h"
#include "include/cef_scheme.h"
#include "tests/unittests/test_handler.h"
#include "tests/unittests/test_suite.h"
#include "base/scoped_temp_dir.h"
#include "base/synchronization/waitable_event.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace {

const char* kTestUrl = "http://www.test.com/path/to/cookietest/foo.html";
const char* kTestDomain = "www.test.com";
const char* kTestPath = "/path/to/cookietest";

typedef std::vector<CefCookie> CookieVector;

void IOT_Set(CefRefPtr<CefCookieManager> manager,
             const CefString& url, CookieVector* cookies,
             base::WaitableEvent* event) {
  CookieVector::const_iterator it = cookies->begin();
  for (; it != cookies->end(); ++it)
    EXPECT_TRUE(manager->SetCookie(url, *it));
  event->Signal();
}

void IOT_Delete(CefRefPtr<CefCookieManager> manager,
                const CefString& url, const CefString& cookie_name,
                base::WaitableEvent* event) {
  EXPECT_TRUE(manager->DeleteCookies(url, cookie_name));
  event->Signal();
}

class TestVisitor : public CefCookieVisitor {
 public:
  TestVisitor(CookieVector* cookies, bool deleteCookies,
              base::WaitableEvent* event)
    : cookies_(cookies),
      delete_cookies_(deleteCookies),
      event_(event) {
  }
  virtual ~TestVisitor()   {
    event_->Signal();
  }

  virtual bool Visit(const CefCookie& cookie, int count, int total,
                     bool& deleteCookie)   {
    cookies_->push_back(cookie);
    if (delete_cookies_)
      deleteCookie = true;
    return true;
  }

  CookieVector* cookies_;
  bool delete_cookies_;
  base::WaitableEvent* event_;

  IMPLEMENT_REFCOUNTING(TestVisitor);
};

// Set the cookies.
void SetCookies(CefRefPtr<CefCookieManager> manager,
                const CefString& url, CookieVector& cookies,
                base::WaitableEvent& event) {
  CefPostTask(TID_IO, NewCefRunnableFunction(IOT_Set, manager, url,
                                             &cookies, &event));
  event.Wait();
}

// Delete the cookie.
void DeleteCookies(CefRefPtr<CefCookieManager> manager,
                   const CefString& url, const CefString& cookie_name,
                   base::WaitableEvent& event) {
  CefPostTask(TID_IO, NewCefRunnableFunction(IOT_Delete, manager, url,
                                             cookie_name, &event));
  event.Wait();
}

// Create a test cookie. If |withDomain| is true a domain cookie will be
// created, otherwise a host cookie will be created.
void CreateCookie(CefRefPtr<CefCookieManager> manager,
                  CefCookie& cookie, bool withDomain,
                  base::WaitableEvent& event) {
  CefString(&cookie.name).FromASCII("my_cookie");
  CefString(&cookie.value).FromASCII("My Value");
  if (withDomain)
    CefString(&cookie.domain).FromASCII(kTestDomain);
  CefString(&cookie.path).FromASCII(kTestPath);
  cookie.has_expires = true;
  cookie.expires.year = 2200;
  cookie.expires.month = 4;
  cookie.expires.day_of_week = 5;
  cookie.expires.day_of_month = 11;

  CookieVector cookies;
  cookies.push_back(cookie);

  SetCookies(manager, kTestUrl, cookies, event);
}

// Retrieve the test cookie. If |withDomain| is true check that the cookie
// is a domain cookie, otherwise a host cookie. if |deleteCookies| is true
// the cookie will be deleted when it's retrieved.
void GetCookie(CefRefPtr<CefCookieManager> manager,
               const CefCookie& cookie, bool withDomain,
               base::WaitableEvent& event, bool deleteCookies) {
  CookieVector cookies;

  // Get the cookie and delete it.
  EXPECT_TRUE(manager->VisitUrlCookies(kTestUrl, false,
      new TestVisitor(&cookies, deleteCookies, &event)));
  event.Wait();

  EXPECT_EQ((CookieVector::size_type)1, cookies.size());

  const CefCookie& cookie_read = cookies[0];
  EXPECT_EQ(CefString(&cookie_read.name), "my_cookie");
  EXPECT_EQ(CefString(&cookie_read.value), "My Value");
  if (withDomain)
    EXPECT_EQ(CefString(&cookie_read.domain), ".www.test.com");
  else
    EXPECT_EQ(CefString(&cookie_read.domain), kTestDomain);
  EXPECT_EQ(CefString(&cookie_read.path), kTestPath);
  EXPECT_TRUE(cookie_read.has_expires);
  EXPECT_EQ(cookie.expires.year, cookie_read.expires.year);
  EXPECT_EQ(cookie.expires.month, cookie_read.expires.month);
  EXPECT_EQ(cookie.expires.day_of_week, cookie_read.expires.day_of_week);
  EXPECT_EQ(cookie.expires.day_of_month, cookie_read.expires.day_of_month);
  EXPECT_EQ(cookie.expires.hour, cookie_read.expires.hour);
  EXPECT_EQ(cookie.expires.minute, cookie_read.expires.minute);
  EXPECT_EQ(cookie.expires.second, cookie_read.expires.second);
  EXPECT_EQ(cookie.expires.millisecond, cookie_read.expires.millisecond);
}

// Visit URL cookies.
void VisitUrlCookies(CefRefPtr<CefCookieManager> manager,
                     const CefString& url,
                     bool includeHttpOnly,
                     CookieVector& cookies,
                     bool deleteCookies,
                     base::WaitableEvent& event) {
  EXPECT_TRUE(manager->VisitUrlCookies(url, includeHttpOnly,
      new TestVisitor(&cookies, deleteCookies, &event)));
  event.Wait();
}

// Visit all cookies.
void VisitAllCookies(CefRefPtr<CefCookieManager> manager,
                     CookieVector& cookies,
                     bool deleteCookies,
                     base::WaitableEvent& event) {
  EXPECT_TRUE(manager->VisitAllCookies(
      new TestVisitor(&cookies, deleteCookies, &event)));
  event.Wait();
}

// Verify that no cookies exist. If |withUrl| is true it will only check for
// cookies matching the URL.
void VerifyNoCookies(CefRefPtr<CefCookieManager> manager,
                     base::WaitableEvent& event, bool withUrl) {
  CookieVector cookies;

  // Verify that the cookie has been deleted.
  if (withUrl) {
    EXPECT_TRUE(manager->VisitUrlCookies(kTestUrl, false,
        new TestVisitor(&cookies, false, &event)));
  } else {
    EXPECT_TRUE(manager->VisitAllCookies(
        new TestVisitor(&cookies, false, &event)));
  }
  event.Wait();

  EXPECT_EQ((CookieVector::size_type)0, cookies.size());
}

// Delete all system cookies.
void DeleteAllCookies(CefRefPtr<CefCookieManager> manager,
                      base::WaitableEvent& event) {
  CefPostTask(TID_IO, NewCefRunnableFunction(IOT_Delete, manager, CefString(),
                                             CefString(), &event));
  event.Wait();
}

void TestDomainCookie(CefRefPtr<CefCookieManager> manager) {
  base::WaitableEvent event(false, false);
  CefCookie cookie;

  // Create a domain cookie.
  CreateCookie(manager, cookie, true, event);

  // Retrieve, verify and delete the domain cookie.
  GetCookie(manager, cookie, true, event, true);

  // Verify that the cookie was deleted.
  VerifyNoCookies(manager, event, true);
}

void TestHostCookie(CefRefPtr<CefCookieManager> manager) {
  base::WaitableEvent event(false, false);
  CefCookie cookie;

  // Create a host cookie.
  CreateCookie(manager, cookie, false, event);

  // Retrieve, verify and delete the host cookie.
  GetCookie(manager, cookie, false, event, true);

  // Verify that the cookie was deleted.
  VerifyNoCookies(manager, event, true);
}

void TestMultipleCookies(CefRefPtr<CefCookieManager> manager) {
  base::WaitableEvent event(false, false);
  std::stringstream ss;
  int i;

  CookieVector cookies;

  const int kNumCookies = 4;

  // Create the cookies.
  for (i = 0; i < kNumCookies; i++) {
    CefCookie cookie;

    ss << "my_cookie" << i;
    CefString(&cookie.name).FromASCII(ss.str().c_str());
    ss.str("");
    ss << "My Value " << i;
    CefString(&cookie.value).FromASCII(ss.str().c_str());
    ss.str("");

    cookies.push_back(cookie);
  }

  // Set the cookies.
  SetCookies(manager, kTestUrl, cookies, event);
  cookies.clear();

  // Get the cookies without deleting them.
  VisitUrlCookies(manager, kTestUrl, false, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)kNumCookies, cookies.size());

  CookieVector::const_iterator it = cookies.begin();
  for (i = 0; it != cookies.end(); ++it, ++i) {
    const CefCookie& cookie = *it;

    ss << "my_cookie" << i;
    EXPECT_EQ(CefString(&cookie.name), ss.str());
    ss.str("");
    ss << "My Value " << i;
    EXPECT_EQ(CefString(&cookie.value), ss.str());
    ss.str("");
  }

  cookies.clear();

  // Delete the 2nd cookie.
  DeleteCookies(manager, kTestUrl, CefString("my_cookie1"), event);

  // Verify that the cookie has been deleted.
  VisitUrlCookies(manager, kTestUrl, false, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)3, cookies.size());
  EXPECT_EQ(CefString(&cookies[0].name), "my_cookie0");
  EXPECT_EQ(CefString(&cookies[1].name), "my_cookie2");
  EXPECT_EQ(CefString(&cookies[2].name), "my_cookie3");

  cookies.clear();

  // Delete the rest of the cookies.
  DeleteCookies(manager, kTestUrl, CefString(), event);

  // Verify that the cookies have been deleted.
  VisitUrlCookies(manager, kTestUrl, false, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)0, cookies.size());

  // Create the cookies.
  for (i = 0; i < kNumCookies; i++) {
    CefCookie cookie;

    ss << "my_cookie" << i;
    CefString(&cookie.name).FromASCII(ss.str().c_str());
    ss.str("");
    ss << "My Value " << i;
    CefString(&cookie.value).FromASCII(ss.str().c_str());
    ss.str("");

    cookies.push_back(cookie);
  }

  // Delete all of the cookies using the visitor.
  VisitUrlCookies(manager, kTestUrl, false, cookies, true, event);

  cookies.clear();

  // Verify that the cookies have been deleted.
  VisitUrlCookies(manager, kTestUrl, false, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)0, cookies.size());
}

void TestAllCookies(CefRefPtr<CefCookieManager> manager) {
  base::WaitableEvent event(false, false);
  CookieVector cookies;

  // Delete all system cookies just in case something is left over from a
  // different test.
  DeleteCookies(manager, CefString(), CefString(), event);

  // Verify that all system cookies have been deleted.
  VisitAllCookies(manager, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)0, cookies.size());

  // Create cookies with 2 separate hosts.
  CefCookie cookie1;
  const char* kUrl1 = "http://www.foo.com";
  CefString(&cookie1.name).FromASCII("my_cookie1");
  CefString(&cookie1.value).FromASCII("My Value 1");

  cookies.push_back(cookie1);
  SetCookies(manager,  kUrl1, cookies, event);
  cookies.clear();

  CefCookie cookie2;
  const char* kUrl2 = "http://www.bar.com";
  CefString(&cookie2.name).FromASCII("my_cookie2");
  CefString(&cookie2.value).FromASCII("My Value 2");

  cookies.push_back(cookie2);
  SetCookies(manager,  kUrl2, cookies, event);
  cookies.clear();

  // Verify that all system cookies can be retrieved.
  VisitAllCookies(manager, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)2, cookies.size());
  EXPECT_EQ(CefString(&cookies[0].name), "my_cookie1");
  EXPECT_EQ(CefString(&cookies[0].value), "My Value 1");
  EXPECT_EQ(CefString(&cookies[0].domain), "www.foo.com");
  EXPECT_EQ(CefString(&cookies[1].name), "my_cookie2");
  EXPECT_EQ(CefString(&cookies[1].value), "My Value 2");
  EXPECT_EQ(CefString(&cookies[1].domain), "www.bar.com");
  cookies.clear();

  // Verify that the cookies can be retrieved separately.
  VisitUrlCookies(manager, kUrl1, false, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)1, cookies.size());
  EXPECT_EQ(CefString(&cookies[0].name), "my_cookie1");
  EXPECT_EQ(CefString(&cookies[0].value), "My Value 1");
  EXPECT_EQ(CefString(&cookies[0].domain), "www.foo.com");
  cookies.clear();

  VisitUrlCookies(manager, kUrl2, false, cookies, false, event);

  EXPECT_EQ((CookieVector::size_type)1, cookies.size());
  EXPECT_EQ(CefString(&cookies[0].name), "my_cookie2");
  EXPECT_EQ(CefString(&cookies[0].value), "My Value 2");
  EXPECT_EQ(CefString(&cookies[0].domain), "www.bar.com");
  cookies.clear();

  // Delete all of the system cookies.
  DeleteAllCookies(manager, event);

  // Verify that all system cookies have been deleted.
  VerifyNoCookies(manager, event, false);
}

void TestChangeDirectory(CefRefPtr<CefCookieManager> manager,
                         const CefString& original_dir) {
  base::WaitableEvent event(false, false);
  CefCookie cookie;

  ScopedTempDir temp_dir;

  // Create a new temporary directory.
  EXPECT_TRUE(temp_dir.CreateUniqueTempDir());

  // Delete all of the system cookies.
  DeleteAllCookies(manager, event);

  // Set the new temporary directory as the storage location.
  EXPECT_TRUE(manager->SetStoragePath(temp_dir.path().value()));

  // Wait for the storage location change to complete on the IO thread.
  WaitForIOThread();

  // Verify that no cookies exist.
  VerifyNoCookies(manager, event, true);

  // Create a domain cookie.
  CreateCookie(manager, cookie, true, event);

  // Retrieve and verify the domain cookie.
  GetCookie(manager, cookie, true, event, false);

  // Restore the original storage location.
  EXPECT_TRUE(manager->SetStoragePath(original_dir));

  // Wait for the storage location change to complete on the IO thread.
  WaitForIOThread();

  // Verify that no cookies exist.
  VerifyNoCookies(manager, event, true);

  // Set the new temporary directory as the storage location.
  EXPECT_TRUE(manager->SetStoragePath(temp_dir.path().value()));

  // Wait for the storage location change to complete on the IO thread.
  WaitForIOThread();

  // Retrieve and verify the domain cookie that was set previously.
  GetCookie(manager, cookie, true, event, false);

  // Restore the original storage location.
  EXPECT_TRUE(manager->SetStoragePath(original_dir));

  // Wait for the storage location change to complete on the IO thread.
  WaitForIOThread();
}

}  // namespace

// Test creation of a domain cookie.
TEST(CookieTest, DomainCookieGlobal) {
  CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
  EXPECT_TRUE(manager.get());

  TestDomainCookie(manager);
}

// Test creation of a domain cookie.
TEST(CookieTest, DomainCookieInMemory) {
  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(CefString());
  EXPECT_TRUE(manager.get());

  TestDomainCookie(manager);
}

// Test creation of a domain cookie.
TEST(CookieTest, DomainCookieOnDisk) {
  ScopedTempDir temp_dir;

  // Create a new temporary directory.
  EXPECT_TRUE(temp_dir.CreateUniqueTempDir());

  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(temp_dir.path().value());
  EXPECT_TRUE(manager.get());

  TestDomainCookie(manager);
}

// Test creation of a host cookie.
TEST(CookieTest, HostCookieGlobal) {
  CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
  EXPECT_TRUE(manager.get());

  TestHostCookie(manager);
}

// Test creation of a host cookie.
TEST(CookieTest, HostCookieInMemory) {
  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(CefString());
  EXPECT_TRUE(manager.get());

  TestHostCookie(manager);
}

// Test creation of a host cookie.
TEST(CookieTest, HostCookieOnDisk) {
  ScopedTempDir temp_dir;

  // Create a new temporary directory.
  EXPECT_TRUE(temp_dir.CreateUniqueTempDir());

  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(temp_dir.path().value());
  EXPECT_TRUE(manager.get());

  TestHostCookie(manager);
}

// Test creation of multiple cookies.
TEST(CookieTest, MultipleCookiesGlobal) {
  CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
  EXPECT_TRUE(manager.get());

  TestMultipleCookies(manager);
}

// Test creation of multiple cookies.
TEST(CookieTest, MultipleCookiesInMemory) {
  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(CefString());
  EXPECT_TRUE(manager.get());

  TestMultipleCookies(manager);
}

// Test creation of multiple cookies.
TEST(CookieTest, MultipleCookiesOnDisk) {
  ScopedTempDir temp_dir;

  // Create a new temporary directory.
  EXPECT_TRUE(temp_dir.CreateUniqueTempDir());

  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(temp_dir.path().value());
  EXPECT_TRUE(manager.get());

  TestMultipleCookies(manager);
}

TEST(CookieTest, AllCookiesGlobal) {
  CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
  EXPECT_TRUE(manager.get());

  TestAllCookies(manager);
}

TEST(CookieTest, AllCookiesInMemory) {
  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(CefString());
  EXPECT_TRUE(manager.get());

  TestAllCookies(manager);
}

TEST(CookieTest, AllCookiesOnDisk) {
  ScopedTempDir temp_dir;

  // Create a new temporary directory.
  EXPECT_TRUE(temp_dir.CreateUniqueTempDir());

  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(temp_dir.path().value());
  EXPECT_TRUE(manager.get());

  TestAllCookies(manager);
}

TEST(CookieTest, ChangeDirectoryGlobal) {
  CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
  EXPECT_TRUE(manager.get());

  std::string cache_path;
  CefTestSuite::GetCachePath(cache_path);

  TestChangeDirectory(manager, cache_path);
}

TEST(CookieTest, ChangeDirectoryCreated) {
  CefRefPtr<CefCookieManager> manager =
      CefCookieManager::CreateManager(CefString());
  EXPECT_TRUE(manager.get());

  TestChangeDirectory(manager, CefString());
}


namespace {

const char* kCookieJSUrl1 = "http://tests/cookie1.html";
const char* kCookieJSUrl2 = "http://tests/cookie2.html";

class CookieTestJSHandler : public TestHandler {
 public:
  CookieTestJSHandler() {}

  virtual void RunTest() OVERRIDE {
    // Create =new in-memory managers.
    manager1_ = CefCookieManager::CreateManager(CefString());
    manager2_ = CefCookieManager::CreateManager(CefString());

    std::string page =
        "<html><head>"
        "<script>"
        "document.cookie='name1=value1';"
        "</script>"
        "</head><body>COOKIE TEST1</body></html>";
    AddResource(kCookieJSUrl1, page, "text/html");

    page =
        "<html><head>"
        "<script>"
        "document.cookie='name2=value2';"
        "</script>"
        "</head><body>COOKIE TEST2</body></html>";
    AddResource(kCookieJSUrl2, page, "text/html");

    // Create the browser
    CreateBrowser(kCookieJSUrl1);
  }

  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE {
    std::string url = frame->GetURL();
    if (url == kCookieJSUrl1) {
      got_load_end1_.yes();
      VerifyCookie(manager1_, url, "name1", "value1", got_cookie1_);

      // Go to the next URL
      frame->LoadURL(kCookieJSUrl2);
    } else {
      got_load_end2_.yes();
      VerifyCookie(manager2_, url, "name2", "value2", got_cookie2_);

      DestroyTest();
    }
  }

  virtual CefRefPtr<CefCookieManager> GetCookieManager(
      CefRefPtr<CefBrowser> browser,
      const CefString& main_url) OVERRIDE {
    if (main_url == kCookieJSUrl1) {
      // Return the first cookie manager.
      got_cookie_manager1_.yes();
      return manager1_;
    } else {
      // Return the second cookie manager.
      got_cookie_manager2_.yes();
      return manager2_;
    }
  }

  // Verify that the cookie was set successfully.
  void VerifyCookie(CefRefPtr<CefCookieManager> manager,
                    const std::string& url,
                    const std::string& name,
                    const std::string& value,
                    TrackCallback& callback) {
    base::WaitableEvent event(false, false);
    CookieVector cookies;

    // Get the cookie.
    VisitUrlCookies(manager, url, false, cookies, false, event);

    if (cookies.size() == 1 && CefString(&cookies[0].name) == name &&
        CefString(&cookies[0].value) == value) {
      callback.yes();
    }
  }

  CefRefPtr<CefCookieManager> manager1_;
  CefRefPtr<CefCookieManager> manager2_;

  TrackCallback got_cookie_manager1_;
  TrackCallback got_cookie_manager2_;
  TrackCallback got_load_end1_;
  TrackCallback got_load_end2_;
  TrackCallback got_cookie1_;
  TrackCallback got_cookie2_;
};

}  // namespace

// Verify use of multiple cookie managers vis JS.
TEST(CookieTest, GetCookieManagerJS) {
  CefRefPtr<CookieTestJSHandler> handler = new CookieTestJSHandler();
  handler->ExecuteTest();

  EXPECT_TRUE(handler->got_cookie_manager1_);
  EXPECT_TRUE(handler->got_cookie_manager2_);
  EXPECT_TRUE(handler->got_load_end1_);
  EXPECT_TRUE(handler->got_load_end2_);
  EXPECT_TRUE(handler->got_cookie1_);
  EXPECT_TRUE(handler->got_cookie2_);
}


namespace {

class CookieTestSchemeHandler : public TestHandler {
 public:
  class SchemeHandler : public CefResourceHandler {
   public:
    explicit SchemeHandler(CookieTestSchemeHandler* handler)
        : handler_(handler),
          offset_(0) {}

    virtual bool ProcessRequest(CefRefPtr<CefRequest> request,
                                CefRefPtr<CefCallback> callback)
                                OVERRIDE {
      std::string url = request->GetURL();
      if (url == handler_->url1_) {
        content_ = "<html><body>COOKIE TEST1</body></html>";
        cookie_ = "name1=value1";
        handler_->got_process_request1_.yes();
      } else if (url == handler_->url2_) {
        content_ = "<html><body>COOKIE TEST2</body></html>";
        cookie_ = "name2=value2";
        handler_->got_process_request2_.yes();
      } else if (url == handler_->url3_) {
        content_ = "<html><body>COOKIE TEST3</body></html>";
        handler_->got_process_request3_.yes();

        // Verify that the cookie was passed in.
        CefRequest::HeaderMap headerMap;
        request->GetHeaderMap(headerMap);
        CefRequest::HeaderMap::iterator it = headerMap.find("Cookie");
        if (it != headerMap.end() && it->second == "name2=value2")
          handler_->got_process_request_cookie_.yes();

      }
      callback->Continue();
      return true;
    }

    virtual void GetResponseHeaders(CefRefPtr<CefResponse> response,
                                    int64& response_length,
                                    CefString& redirectUrl) OVERRIDE {
      response_length = content_.size();

      response->SetStatus(200);
      response->SetMimeType("text/html");

      if (!cookie_.empty()) {
        CefResponse::HeaderMap headerMap;
        response->GetHeaderMap(headerMap);
        headerMap.insert(std::make_pair("Set-Cookie", cookie_));
        response->SetHeaderMap(headerMap);
      }
    }

    virtual bool ReadResponse(void* data_out,
                              int bytes_to_read,
                              int& bytes_read,
                              CefRefPtr<CefCallback> callback)
                              OVERRIDE {
      bool has_data = false;
      bytes_read = 0;

      size_t size = content_.size();
      if (offset_ < size) {
        int transfer_size =
            std::min(bytes_to_read, static_cast<int>(size - offset_));
        memcpy(data_out, content_.c_str() + offset_, transfer_size);
        offset_ += transfer_size;

        bytes_read = transfer_size;
        has_data = true;
      }

      return has_data;
    }

    virtual void Cancel() OVERRIDE {
    }

   private:
    CookieTestSchemeHandler* handler_;
    std::string content_;
    size_t offset_;
    std::string cookie_;

    IMPLEMENT_REFCOUNTING(SchemeHandler);
  };

  class SchemeHandlerFactory : public CefSchemeHandlerFactory {
   public:
    explicit SchemeHandlerFactory(CookieTestSchemeHandler* handler)
        : handler_(handler) {}

    virtual CefRefPtr<CefResourceHandler> Create(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        const CefString& scheme_name,
        CefRefPtr<CefRequest> request) OVERRIDE {
      std::string url = request->GetURL();
      if (url == handler_->url3_) {
        // Verify that the cookie was not passed in.
        CefRequest::HeaderMap headerMap;
        request->GetHeaderMap(headerMap);
        CefRequest::HeaderMap::iterator it = headerMap.find("Cookie");
        if (it != headerMap.end() && it->second == "name2=value2")
          handler_->got_create_cookie_.yes();
      }
                                                 
      return new SchemeHandler(handler_);
    }

   private:
    CookieTestSchemeHandler* handler_;

    IMPLEMENT_REFCOUNTING(SchemeHandlerFactory);
  };

  CookieTestSchemeHandler(const std::string& scheme) : scheme_(scheme) {
    url1_ = scheme + "://cookie-tests/cookie1.html";
    url2_ = scheme + "://cookie-tests/cookie2.html";
    url3_ = scheme + "://cookie-tests/cookie3.html";
  }

  virtual void RunTest() OVERRIDE {
    // Create new in-memory managers.
    manager1_ = CefCookieManager::CreateManager(CefString());
    manager2_ = CefCookieManager::CreateManager(CefString());

    if (scheme_ != "http") {
      std::vector<CefString> schemes;
      schemes.push_back("http");
      schemes.push_back("https");
      schemes.push_back(scheme_);

      manager1_->SetSupportedSchemes(schemes);
      manager2_->SetSupportedSchemes(schemes);
    }

    // Register the scheme handler.
    CefRegisterSchemeHandlerFactory(scheme_, "cookie-tests",
        new SchemeHandlerFactory(this));

    // Create the browser
    CreateBrowser(url1_);
  }

  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) OVERRIDE {
    std::string url = frame->GetURL();
    if (url == url1_) {
      got_load_end1_.yes();
      VerifyCookie(manager1_, url, "name1", "value1", got_cookie1_);

      // Go to the next URL
      frame->LoadURL(url2_);
    } else if (url == url2_) {
      got_load_end2_.yes();
      VerifyCookie(manager2_, url, "name2", "value2", got_cookie2_);

      // Go to the next URL
      frame->LoadURL(url3_);
    } else {
      got_load_end3_.yes();
      VerifyCookie(manager2_, url, "name2", "value2", got_cookie3_);

      // Unregister the scheme handler.
      CefRegisterSchemeHandlerFactory(scheme_, "cookie-tests", NULL);

      DestroyTest();
    }
  }

  virtual CefRefPtr<CefCookieManager> GetCookieManager(
      CefRefPtr<CefBrowser> browser,
      const CefString& main_url) OVERRIDE {
    if (main_url == url1_) {
      // Return the first cookie manager.
      got_cookie_manager1_.yes();
      return manager1_;
    } else {
      // Return the second cookie manager.
      got_cookie_manager2_.yes();
      return manager2_;
    }
  }

  // Verify that the cookie was set successfully.
  void VerifyCookie(CefRefPtr<CefCookieManager> manager,
                    const std::string& url,
                    const std::string& name,
                    const std::string& value,
                    TrackCallback& callback) {
    base::WaitableEvent event(false, false);
    CookieVector cookies;

    // Get the cookie.
    VisitUrlCookies(manager, url, false, cookies, false, event);

    if (cookies.size() == 1 && CefString(&cookies[0].name) == name &&
        CefString(&cookies[0].value) == value) {
      callback.yes();
    }
  }

  std::string scheme_;
  std::string url1_;
  std::string url2_;
  std::string url3_;

  CefRefPtr<CefCookieManager> manager1_;
  CefRefPtr<CefCookieManager> manager2_;

  TrackCallback got_process_request1_;
  TrackCallback got_process_request2_;
  TrackCallback got_process_request3_;
  TrackCallback got_create_cookie_;
  TrackCallback got_process_request_cookie_;
  TrackCallback got_cookie_manager1_;
  TrackCallback got_cookie_manager2_;
  TrackCallback got_load_end1_;
  TrackCallback got_load_end2_;
  TrackCallback got_load_end3_;
  TrackCallback got_cookie1_;
  TrackCallback got_cookie2_;
  TrackCallback got_cookie3_;
};

}  // namespace

// Verify use of multiple cookie managers via HTTP.
TEST(CookieTest, GetCookieManagerHttp) {
  CefRefPtr<CookieTestSchemeHandler> handler =
      new CookieTestSchemeHandler("http");
  handler->ExecuteTest();

  EXPECT_TRUE(handler->got_process_request1_);
  EXPECT_TRUE(handler->got_process_request2_);
  EXPECT_TRUE(handler->got_process_request3_);
  EXPECT_FALSE(handler->got_create_cookie_);
  EXPECT_TRUE(handler->got_process_request_cookie_);
  EXPECT_TRUE(handler->got_cookie_manager1_);
  EXPECT_TRUE(handler->got_cookie_manager2_);
  EXPECT_TRUE(handler->got_load_end1_);
  EXPECT_TRUE(handler->got_load_end2_);
  EXPECT_TRUE(handler->got_load_end3_);
  EXPECT_TRUE(handler->got_cookie1_);
  EXPECT_TRUE(handler->got_cookie2_);
  EXPECT_TRUE(handler->got_cookie3_);
}

// Verify use of multiple cookie managers via a custom scheme.
TEST(CookieTest, GetCookieManagerCustom) {
  CefRefPtr<CookieTestSchemeHandler> handler =
      new CookieTestSchemeHandler("ccustom");
  handler->ExecuteTest();

  EXPECT_TRUE(handler->got_process_request1_);
  EXPECT_TRUE(handler->got_process_request2_);
  EXPECT_TRUE(handler->got_process_request3_);
  EXPECT_FALSE(handler->got_create_cookie_);
  EXPECT_TRUE(handler->got_process_request_cookie_);
  EXPECT_TRUE(handler->got_cookie_manager1_);
  EXPECT_TRUE(handler->got_cookie_manager2_);
  EXPECT_TRUE(handler->got_load_end1_);
  EXPECT_TRUE(handler->got_load_end2_);
  EXPECT_TRUE(handler->got_load_end3_);
  EXPECT_TRUE(handler->got_cookie1_);
  EXPECT_TRUE(handler->got_cookie2_);
  EXPECT_TRUE(handler->got_cookie3_);
}

// Entry point for registering custom schemes.
// Called from client_app_delegates.cc.
void RegisterCookieCustomSchemes(
      CefRefPtr<CefSchemeRegistrar> registrar,
      std::vector<CefString>& cookiable_schemes) {
  // Used by GetCookieManagerCustom test.
  registrar->AddCustomScheme("ccustom", true, false, false);
}
