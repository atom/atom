// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_REQUEST_IMPL_H_
#define CEF_LIBCEF_COMMON_REQUEST_IMPL_H_
#pragma once

#include "include/cef_request.h"
#include "net/base/upload_data.h"
#include "net/http/http_request_headers.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebHTTPBody.h"

namespace net {
class URLRequest;
};

namespace WebKit {
class WebURLRequest;
}

// Implementation of CefRequest
class CefRequestImpl : public CefRequest {
 public:
  CefRequestImpl();
  ~CefRequestImpl() {}

  virtual bool IsReadOnly() OVERRIDE;
  virtual CefString GetURL() OVERRIDE;
  virtual void SetURL(const CefString& url) OVERRIDE;
  virtual CefString GetMethod() OVERRIDE;
  virtual void SetMethod(const CefString& method) OVERRIDE;
  virtual CefRefPtr<CefPostData> GetPostData() OVERRIDE;
  virtual void SetPostData(CefRefPtr<CefPostData> postData) OVERRIDE;
  virtual void GetHeaderMap(HeaderMap& headerMap) OVERRIDE;
  virtual void SetHeaderMap(const HeaderMap& headerMap) OVERRIDE;
  virtual void Set(const CefString& url,
                   const CefString& method,
                   CefRefPtr<CefPostData> postData,
                   const HeaderMap& headerMap) OVERRIDE;
  virtual int GetFlags() OVERRIDE;
  virtual void SetFlags(int flags) OVERRIDE;
  virtual CefString GetFirstPartyForCookies() OVERRIDE;
  virtual void SetFirstPartyForCookies(const CefString& url) OVERRIDE;

  // Populate this object from the URLRequest object.
  void Set(net::URLRequest* request);

  // Populate the URLRequest object from this object.
  void Get(net::URLRequest* request);

  // Populate this object from a WebURLRequest object.
  void Set(const WebKit::WebURLRequest& request);

  // Populate the WebURLRequest object from this object.
  void Get(WebKit::WebURLRequest& request);

  void SetReadOnly(bool read_only);

  static void GetHeaderMap(const net::HttpRequestHeaders& headers,
                           HeaderMap& map);
  static void GetHeaderMap(const WebKit::WebURLRequest& request,
                           HeaderMap& map);
  static void SetHeaderMap(const HeaderMap& map,
                           WebKit::WebURLRequest& request);

 protected:
  CefString url_;
  CefString method_;
  CefRefPtr<CefPostData> postdata_;
  HeaderMap headermap_;

  // The below members are used by CefURLRequest.
  int flags_;
  CefString first_party_for_cookies_;

  // True if this object is read-only.
  bool read_only_;

  IMPLEMENT_REFCOUNTING(CefRequestImpl);
  IMPLEMENT_LOCKING(CefRequestImpl);
};

// Implementation of CefPostData
class CefPostDataImpl : public CefPostData {
 public:
  CefPostDataImpl();
  ~CefPostDataImpl() {}

  virtual bool IsReadOnly() OVERRIDE;
  virtual size_t GetElementCount() OVERRIDE;
  virtual void GetElements(ElementVector& elements) OVERRIDE;
  virtual bool RemoveElement(CefRefPtr<CefPostDataElement> element) OVERRIDE;
  virtual bool AddElement(CefRefPtr<CefPostDataElement> element) OVERRIDE;
  virtual void RemoveElements();

  void Set(net::UploadData& data);
  void Get(net::UploadData& data);
  void Set(const WebKit::WebHTTPBody& data);
  void Get(WebKit::WebHTTPBody& data);

  void SetReadOnly(bool read_only);

 protected:
  ElementVector elements_;

  // True if this object is read-only.
  bool read_only_;

  IMPLEMENT_REFCOUNTING(CefPostDataImpl);
  IMPLEMENT_LOCKING(CefPostDataImpl);
};

// Implementation of CefPostDataElement
class CefPostDataElementImpl : public CefPostDataElement {
 public:
  CefPostDataElementImpl();
  ~CefPostDataElementImpl();

  virtual bool IsReadOnly() OVERRIDE;
  virtual void SetToEmpty() OVERRIDE;
  virtual void SetToFile(const CefString& fileName) OVERRIDE;
  virtual void SetToBytes(size_t size, const void* bytes) OVERRIDE;
  virtual Type GetType() OVERRIDE;
  virtual CefString GetFile() OVERRIDE;
  virtual size_t GetBytesCount() OVERRIDE;
  virtual size_t GetBytes(size_t size, void* bytes) OVERRIDE;

  void* GetBytes() { return data_.bytes.bytes; }

  void Set(const net::UploadData::Element& element);
  void Get(net::UploadData::Element& element);
  void Set(const WebKit::WebHTTPBody::Element& element);
  void Get(WebKit::WebHTTPBody::Element& element);

  void SetReadOnly(bool read_only);

 protected:
  void Cleanup();

  Type type_;
  union {
    struct {
      void* bytes;
      size_t size;
    } bytes;
    cef_string_t filename;
  } data_;

  // True if this object is read-only.
  bool read_only_;

  IMPLEMENT_REFCOUNTING(CefPostDataElementImpl);
  IMPLEMENT_LOCKING(CefPostDataElementImpl);
};

#endif  // CEF_LIBCEF_COMMON_REQUEST_IMPL_H_
