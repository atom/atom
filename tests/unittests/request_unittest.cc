// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_request.h"
#include "tests/unittests/test_handler.h"
#include "tests/unittests/test_util.h"
#include "testing/gtest/include/gtest/gtest.h"

// Verify Set/Get methods for CefRequest, CefPostData and CefPostDataElement.
TEST(RequestTest, SetGet) {
  // CefRequest CreateRequest
  CefRefPtr<CefRequest> request(CefRequest::Create());
  ASSERT_TRUE(request.get() != NULL);

  CefString url = "http://tests/run.html";
  CefString method = "POST";
  CefRequest::HeaderMap setHeaders, getHeaders;
  setHeaders.insert(std::make_pair("HeaderA", "ValueA"));
  setHeaders.insert(std::make_pair("HeaderB", "ValueB"));

  // CefPostData CreatePostData
  CefRefPtr<CefPostData> postData(CefPostData::Create());
  ASSERT_TRUE(postData.get() != NULL);

  // CefPostDataElement CreatePostDataElement
  CefRefPtr<CefPostDataElement> element1(CefPostDataElement::Create());
  ASSERT_TRUE(element1.get() != NULL);
  CefRefPtr<CefPostDataElement> element2(CefPostDataElement::Create());
  ASSERT_TRUE(element2.get() != NULL);

  // CefPostDataElement SetToFile
  CefString file = "c:\\path\\to\\file.ext";
  element1->SetToFile(file);
  ASSERT_EQ(PDE_TYPE_FILE, element1->GetType());
  ASSERT_EQ(file, element1->GetFile());

  // CefPostDataElement SetToBytes
  char bytes[] = "Test Bytes";
  element2->SetToBytes(sizeof(bytes), bytes);
  ASSERT_EQ(PDE_TYPE_BYTES, element2->GetType());
  ASSERT_EQ(sizeof(bytes), element2->GetBytesCount());
  char bytesOut[sizeof(bytes)];
  element2->GetBytes(sizeof(bytes), bytesOut);
  ASSERT_TRUE(!memcmp(bytes, bytesOut, sizeof(bytes)));

  // CefPostData AddElement
  postData->AddElement(element1);
  postData->AddElement(element2);
  ASSERT_EQ((size_t)2, postData->GetElementCount());

  // CefPostData RemoveElement
  postData->RemoveElement(element1);
  ASSERT_EQ((size_t)1, postData->GetElementCount());

  // CefPostData RemoveElements
  postData->RemoveElements();
  ASSERT_EQ((size_t)0, postData->GetElementCount());

  postData->AddElement(element1);
  postData->AddElement(element2);
  ASSERT_EQ((size_t)2, postData->GetElementCount());
  CefPostData::ElementVector elements;
  postData->GetElements(elements);
  CefPostData::ElementVector::const_iterator it = elements.begin();
  for (size_t i = 0; it != elements.end(); ++it, ++i) {
    if (i == 0)
      TestPostDataElementEqual(element1, (*it).get());
    else if (i == 1)
      TestPostDataElementEqual(element2, (*it).get());
  }

  // CefRequest SetURL
  request->SetURL(url);
  ASSERT_EQ(url, request->GetURL());

  // CefRequest SetMethod
  request->SetMethod(method);
  ASSERT_EQ(method, request->GetMethod());

  // CefRequest SetHeaderMap
  request->SetHeaderMap(setHeaders);
  request->GetHeaderMap(getHeaders);
  TestMapEqual(setHeaders, getHeaders, false);
  getHeaders.clear();

  // CefRequest SetPostData
  request->SetPostData(postData);
  TestPostDataEqual(postData, request->GetPostData());

  request = CefRequest::Create();
  ASSERT_TRUE(request.get() != NULL);

  // CefRequest Set
  request->Set(url, method, postData, setHeaders);
  ASSERT_EQ(url, request->GetURL());
  ASSERT_EQ(method, request->GetMethod());
  request->GetHeaderMap(getHeaders);
  TestMapEqual(setHeaders, getHeaders, false);
  getHeaders.clear();
  TestPostDataEqual(postData, request->GetPostData());
}

namespace {

void CreateRequest(CefRefPtr<CefRequest>& request) {
  request = CefRequest::Create();
  ASSERT_TRUE(request.get() != NULL);

  request->SetURL("http://tests/run.html");
  request->SetMethod("POST");

  CefRequest::HeaderMap headers;
  headers.insert(std::make_pair("HeaderA", "ValueA"));
  headers.insert(std::make_pair("HeaderB", "ValueB"));
  request->SetHeaderMap(headers);

  CefRefPtr<CefPostData> postData(CefPostData::Create());
  ASSERT_TRUE(postData.get() != NULL);

  CefRefPtr<CefPostDataElement> element1(
      CefPostDataElement::Create());
  ASSERT_TRUE(element1.get() != NULL);
  char bytes[] = "Test Bytes";
  element1->SetToBytes(sizeof(bytes), bytes);
  postData->AddElement(element1);

  request->SetPostData(postData);
}

class RequestSendRecvTestHandler : public TestHandler {
 public:
  RequestSendRecvTestHandler() {}

  virtual void RunTest() OVERRIDE {
    // Create the test request
    CreateRequest(request_);

    // Create the browser
    CreateBrowser("about:blank");
  }

  virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) OVERRIDE {
    TestHandler::OnAfterCreated(browser);

    // Load the test request
    browser->GetMainFrame()->LoadRequest(request_);
  }

  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request) OVERRIDE {
    // Verify that the request is the same
    TestRequestEqual(request_, request, true);

    got_before_resource_load_.yes();

    return false;
  }

  virtual CefRefPtr<CefResourceHandler> GetResourceHandler(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      CefRefPtr<CefRequest> request) OVERRIDE {
    // Verify that the request is the same
    TestRequestEqual(request_, request, true);

    got_resource_handler_.yes();

    DestroyTest();

    // No results
    return NULL;
  }

  CefRefPtr<CefRequest> request_;

  TrackCallback got_before_resource_load_;
  TrackCallback got_resource_handler_;
};

}  // namespace

// Verify send and recieve
TEST(RequestTest, SendRecv) {
  CefRefPtr<RequestSendRecvTestHandler> handler =
      new RequestSendRecvTestHandler();
  handler->ExecuteTest();

  ASSERT_TRUE(handler->got_before_resource_load_);
  ASSERT_TRUE(handler->got_resource_handler_);
}
