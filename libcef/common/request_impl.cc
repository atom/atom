// Copyright (c) 2008-2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <string>
#include <vector>

#include "libcef/common/http_header_utils.h"
#include "libcef/common/request_impl.h"

#include "base/logging.h"
#include "net/url_request/url_request.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebHTTPHeaderVisitor.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebString.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURL.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURLRequest.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURLError.h"


#define CHECK_READONLY_RETURN(val) \
  if (read_only_) { \
    NOTREACHED() << "object is read only"; \
    return val; \
  }

#define CHECK_READONLY_RETURN_VOID() \
  if (read_only_) { \
    NOTREACHED() << "object is read only"; \
    return; \
  }


// CefRequest -----------------------------------------------------------------

// static
CefRefPtr<CefRequest> CefRequest::Create() {
  CefRefPtr<CefRequest> request(new CefRequestImpl());
  return request;
}


// CefRequestImpl -------------------------------------------------------------

CefRequestImpl::CefRequestImpl()
    : method_("GET"),
      flags_(UR_FLAG_NONE),
      read_only_(false) {
}

bool CefRequestImpl::IsReadOnly() {
  AutoLock lock_scope(this);
  return read_only_;
}

CefString CefRequestImpl::GetURL() {
  AutoLock lock_scope(this);
  return url_;
}

void CefRequestImpl::SetURL(const CefString& url) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  url_ = url;
}

CefString CefRequestImpl::GetMethod() {
  AutoLock lock_scope(this);
  return method_;
}

void CefRequestImpl::SetMethod(const CefString& method) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  method_ = method;
}

CefRefPtr<CefPostData> CefRequestImpl::GetPostData() {
  AutoLock lock_scope(this);
  return postdata_;
}

void CefRequestImpl::SetPostData(CefRefPtr<CefPostData> postData) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  postdata_ = postData;
}

void CefRequestImpl::GetHeaderMap(HeaderMap& headerMap) {
  AutoLock lock_scope(this);
  headerMap = headermap_;
}

void CefRequestImpl::SetHeaderMap(const HeaderMap& headerMap) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  headermap_ = headerMap;
}

void CefRequestImpl::Set(const CefString& url,
                         const CefString& method,
                         CefRefPtr<CefPostData> postData,
                         const HeaderMap& headerMap) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  url_ = url;
  method_ = method;
  postdata_ = postData;
  headermap_ = headerMap;
}

int CefRequestImpl::GetFlags() {
  AutoLock lock_scope(this);
  return flags_;
}
void CefRequestImpl::SetFlags(int flags) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  flags_ = flags;
}

CefString CefRequestImpl::GetFirstPartyForCookies() {
  AutoLock lock_scope(this);
  return first_party_for_cookies_;
}
void CefRequestImpl::SetFirstPartyForCookies(const CefString& url) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  first_party_for_cookies_ = url;
}

void CefRequestImpl::Set(net::URLRequest* request) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  url_ = request->url().spec();
  method_ = request->method();
  first_party_for_cookies_ = request->first_party_for_cookies().spec();

  net::HttpRequestHeaders headers = request->extra_request_headers();

  // Ensure that we do not send username and password fields in the referrer.
  GURL referrer(request->GetSanitizedReferrer());

  // Strip Referer from request_info_.extra_headers to prevent, e.g., plugins
  // from overriding headers that are controlled using other means. Otherwise a
  // plugin could set a referrer although sending the referrer is inhibited.
  headers.RemoveHeader(net::HttpRequestHeaders::kReferer);

  // Our consumer should have made sure that this is a safe referrer.  See for
  // instance WebCore::FrameLoader::HideReferrer.
  if (referrer.is_valid())
    headers.SetHeader(net::HttpRequestHeaders::kReferer, referrer.spec());

  // Transfer request headers
  GetHeaderMap(headers, headermap_);

  // Transfer post data, if any
  net::UploadData* data = request->get_upload();
  if (data) {
    postdata_ = CefPostData::Create();
    static_cast<CefPostDataImpl*>(postdata_.get())->Set(*data);
  } else if (postdata_.get()) {
    postdata_ = NULL;
  }
}

void CefRequestImpl::Get(net::URLRequest* request) {
  AutoLock lock_scope(this);

  request->set_method(method_);
  if (!first_party_for_cookies_.empty()) {
    request->set_first_party_for_cookies(
        GURL(std::string(first_party_for_cookies_)));
  }

  CefString referrerStr;
  referrerStr.FromASCII(net::HttpRequestHeaders::kReferer);
  HeaderMap headerMap = headermap_;
  HeaderMap::iterator it = headerMap.find(referrerStr);
  if (it == headerMap.end()) {
    request->set_referrer("");
  } else {
    request->set_referrer(it->second);
    headerMap.erase(it);
  }
  net::HttpRequestHeaders headers;
  headers.AddHeadersFromString(HttpHeaderUtils::GenerateHeaders(headerMap));
  request->SetExtraRequestHeaders(headers);

  if (postdata_.get()) {
    net::UploadData* upload = new net::UploadData();
    static_cast<CefPostDataImpl*>(postdata_.get())->Get(*upload);
    request->set_upload(upload);
  } else if (request->get_upload()) {
    request->set_upload(NULL);
  }
}

void CefRequestImpl::Set(const WebKit::WebURLRequest& request) {
  DCHECK(!request.isNull());

  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  url_ = request.url().spec().utf16();
  method_ = request.httpMethod();

  const WebKit::WebHTTPBody& body = request.httpBody();
  if (!body.isNull()) {
    postdata_ = new CefPostDataImpl();
    static_cast<CefPostDataImpl*>(postdata_.get())->Set(body);
  } else if (postdata_.get()) {
    postdata_ = NULL;
  }

  headermap_.clear();
  GetHeaderMap(request, headermap_);

  flags_ = UR_FLAG_NONE;
  if (request.cachePolicy() == WebKit::WebURLRequest::ReloadIgnoringCacheData)
    flags_ |= UR_FLAG_SKIP_CACHE;
  if (request.allowStoredCredentials())
    flags_ |= UR_FLAG_ALLOW_CACHED_CREDENTIALS;
  if (request.allowCookies())
    flags_ |= UR_FLAG_ALLOW_COOKIES;
  if (request.reportUploadProgress())
    flags_ |= UR_FLAG_REPORT_UPLOAD_PROGRESS;
  if (request.reportLoadTiming())
    flags_ |= UR_FLAG_REPORT_LOAD_TIMING;
  if (request.reportRawHeaders())
    flags_ |= UR_FLAG_REPORT_RAW_HEADERS;

  first_party_for_cookies_ = request.firstPartyForCookies().spec().utf16();
}

void CefRequestImpl::Get(WebKit::WebURLRequest& request) {
  request.initialize();
  AutoLock lock_scope(this);

  GURL gurl = GURL(url_.ToString());
  request.setURL(WebKit::WebURL(gurl));

  std::string method(method_);
  request.setHTTPMethod(WebKit::WebString::fromUTF8(method.c_str()));
  request.setTargetType(WebKit::WebURLRequest::TargetIsMainFrame);

  WebKit::WebHTTPBody body;
  if (postdata_.get()) {
    body.initialize();
    static_cast<CefPostDataImpl*>(postdata_.get())->Get(body);
    request.setHTTPBody(body);
  }

  SetHeaderMap(headermap_, request);

  request.setCachePolicy((flags_ & UR_FLAG_SKIP_CACHE) ?
      WebKit::WebURLRequest::ReloadIgnoringCacheData :
      WebKit::WebURLRequest::UseProtocolCachePolicy);

  #define SETBOOLFLAG(obj, flags, method, FLAG) \
      obj.method((flags & (FLAG)) == (FLAG))

  SETBOOLFLAG(request, flags_, setAllowStoredCredentials,
              UR_FLAG_ALLOW_CACHED_CREDENTIALS);
  SETBOOLFLAG(request, flags_, setAllowCookies,
              UR_FLAG_ALLOW_COOKIES);
  SETBOOLFLAG(request, flags_, setReportUploadProgress,
              UR_FLAG_REPORT_UPLOAD_PROGRESS);
  SETBOOLFLAG(request, flags_, setReportLoadTiming,
              UR_FLAG_REPORT_LOAD_TIMING);
  SETBOOLFLAG(request, flags_, setReportRawHeaders,
              UR_FLAG_REPORT_RAW_HEADERS);

  if (!first_party_for_cookies_.empty()) {
    GURL gurl = GURL(first_party_for_cookies_.ToString());
    request.setFirstPartyForCookies(WebKit::WebURL(gurl));
  }
}

void CefRequestImpl::SetReadOnly(bool read_only) {
  AutoLock lock_scope(this);
  if (read_only_ == read_only)
    return;

  read_only_ = read_only;

  if (postdata_.get())
    static_cast<CefPostDataImpl*>(postdata_.get())->SetReadOnly(read_only);
}

// static
void CefRequestImpl::GetHeaderMap(const net::HttpRequestHeaders& headers,
                                  HeaderMap& map) {
  if (headers.IsEmpty())
    return;

  net::HttpRequestHeaders::Iterator it(headers);
  do {
    map.insert(std::make_pair(it.name(), it.value()));
  } while (it.GetNext());
}


// static
void CefRequestImpl::GetHeaderMap(const WebKit::WebURLRequest& request,
                                  HeaderMap& map) {
  class HeaderVisitor : public WebKit::WebHTTPHeaderVisitor {
   public:
    explicit HeaderVisitor(HeaderMap* map) : map_(map) {}

    virtual void visitHeader(const WebKit::WebString& name,
                             const WebKit::WebString& value) {
      map_->insert(std::make_pair(string16(name), string16(value)));
    }

   private:
    HeaderMap* map_;
  };

  HeaderVisitor visitor(&map);
  request.visitHTTPHeaderFields(&visitor);
}

// static
void CefRequestImpl::SetHeaderMap(const HeaderMap& map,
                                  WebKit::WebURLRequest& request) {
  HeaderMap::const_iterator it = map.begin();
  for (; it != map.end(); ++it)
    request.setHTTPHeaderField(string16(it->first), string16(it->second));
}

// CefPostData ----------------------------------------------------------------

// static
CefRefPtr<CefPostData> CefPostData::Create() {
  CefRefPtr<CefPostData> postdata(new CefPostDataImpl());
  return postdata;
}


// CefPostDataImpl ------------------------------------------------------------

CefPostDataImpl::CefPostDataImpl()
  : read_only_(false) {
}

bool CefPostDataImpl::IsReadOnly() {
  AutoLock lock_scope(this);
  return read_only_;
}

size_t CefPostDataImpl::GetElementCount() {
  AutoLock lock_scope(this);
  return elements_.size();
}

void CefPostDataImpl::GetElements(ElementVector& elements) {
  AutoLock lock_scope(this);
  elements = elements_;
}

bool CefPostDataImpl::RemoveElement(CefRefPtr<CefPostDataElement> element) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN(false);

  ElementVector::iterator it = elements_.begin();
  for (; it != elements_.end(); ++it) {
    if (it->get() == element.get()) {
      elements_.erase(it);
      return true;
    }
  }

  return false;
}

bool CefPostDataImpl::AddElement(CefRefPtr<CefPostDataElement> element) {
  bool found = false;

  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN(false);

  // check that the element isn't already in the list before adding
  ElementVector::const_iterator it = elements_.begin();
  for (; it != elements_.end(); ++it) {
    if (it->get() == element.get()) {
      found = true;
      break;
    }
  }

  if (!found)
    elements_.push_back(element);

  return !found;
}

void CefPostDataImpl::RemoveElements() {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();
  elements_.clear();
}

void CefPostDataImpl::Set(net::UploadData& data) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  CefRefPtr<CefPostDataElement> postelem;

  std::vector<net::UploadData::Element>* elements = data.elements();
  std::vector<net::UploadData::Element>::const_iterator it = elements->begin();
  for (; it != elements->end(); ++it) {
    postelem = CefPostDataElement::Create();
    static_cast<CefPostDataElementImpl*>(postelem.get())->Set(*it);
    AddElement(postelem);
  }
}

void CefPostDataImpl::Get(net::UploadData& data) {
  AutoLock lock_scope(this);

  net::UploadData::Element element;
  std::vector<net::UploadData::Element> data_elements;
  ElementVector::const_iterator it = elements_.begin();
  for (; it != elements_.end(); ++it) {
    static_cast<CefPostDataElementImpl*>(it->get())->Get(element);
    data_elements.push_back(element);
  }
  data.SetElements(data_elements);
}

void CefPostDataImpl::Set(const WebKit::WebHTTPBody& data) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  CefRefPtr<CefPostDataElement> postelem;
  WebKit::WebHTTPBody::Element element;
  size_t size = data.elementCount();
  for (size_t i = 0; i < size; ++i) {
    if (data.elementAt(i, element)) {
      postelem = CefPostDataElement::Create();
      static_cast<CefPostDataElementImpl*>(postelem.get())->Set(element);
      AddElement(postelem);
    }
  }
}

void CefPostDataImpl::Get(WebKit::WebHTTPBody& data) {
  AutoLock lock_scope(this);

  WebKit::WebHTTPBody::Element element;
  ElementVector::iterator it = elements_.begin();
  for (; it != elements_.end(); ++it) {
    static_cast<CefPostDataElementImpl*>(it->get())->Get(element);
    if (element.type == WebKit::WebHTTPBody::Element::TypeData) {
      data.appendData(element.data);
    } else if (element.type == WebKit::WebHTTPBody::Element::TypeFile) {
      data.appendFile(element.filePath);
    } else {
      NOTREACHED();
    }
  }
}

void CefPostDataImpl::SetReadOnly(bool read_only) {
  AutoLock lock_scope(this);
  if (read_only_ == read_only)
    return;

  read_only_ = read_only;

  ElementVector::const_iterator it = elements_.begin();
  for (; it != elements_.end(); ++it) {
    static_cast<CefPostDataElementImpl*>(it->get())->SetReadOnly(read_only);
  }
}

// CefPostDataElement ---------------------------------------------------------

// static
CefRefPtr<CefPostDataElement> CefPostDataElement::Create() {
  CefRefPtr<CefPostDataElement> element(new CefPostDataElementImpl());
  return element;
}


// CefPostDataElementImpl -----------------------------------------------------

CefPostDataElementImpl::CefPostDataElementImpl()
  : type_(PDE_TYPE_EMPTY),
    read_only_(false) {
  memset(&data_, 0, sizeof(data_));
}

CefPostDataElementImpl::~CefPostDataElementImpl() {
  Cleanup();
}

bool CefPostDataElementImpl::IsReadOnly() {
  AutoLock lock_scope(this);
  return read_only_;
}

void CefPostDataElementImpl::SetToEmpty() {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  Cleanup();
}

void CefPostDataElementImpl::SetToFile(const CefString& fileName) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  // Clear any data currently in the element
  SetToEmpty();

  // Assign the new data
  type_ = PDE_TYPE_FILE;
  cef_string_copy(fileName.c_str(), fileName.length(), &data_.filename);
}

void CefPostDataElementImpl::SetToBytes(size_t size, const void* bytes) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  // Clear any data currently in the element
  SetToEmpty();

  // Assign the new data
  void* data = malloc(size);
  DCHECK(data != NULL);
  if (data == NULL)
    return;

  memcpy(data, bytes, size);

  type_ = PDE_TYPE_BYTES;
  data_.bytes.bytes = data;
  data_.bytes.size = size;
}

CefPostDataElement::Type CefPostDataElementImpl::GetType() {
  AutoLock lock_scope(this);
  return type_;
}

CefString CefPostDataElementImpl::GetFile() {
  AutoLock lock_scope(this);
  DCHECK(type_ == PDE_TYPE_FILE);
  CefString filename;
  if (type_ == PDE_TYPE_FILE)
    filename.FromString(data_.filename.str, data_.filename.length, false);
  return filename;
}

size_t CefPostDataElementImpl::GetBytesCount() {
  AutoLock lock_scope(this);
  DCHECK(type_ == PDE_TYPE_BYTES);
  size_t size = 0;
  if (type_ == PDE_TYPE_BYTES)
    size = data_.bytes.size;
  return size;
}

size_t CefPostDataElementImpl::GetBytes(size_t size, void* bytes) {
  AutoLock lock_scope(this);
  DCHECK(type_ == PDE_TYPE_BYTES);
  size_t rv = 0;
  if (type_ == PDE_TYPE_BYTES) {
    rv = (size < data_.bytes.size ? size : data_.bytes.size);
    memcpy(bytes, data_.bytes.bytes, rv);
  }
  return rv;
}

void CefPostDataElementImpl::Set(const net::UploadData::Element& element) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  if (element.type() == net::UploadData::TYPE_BYTES) {
    SetToBytes(element.bytes().size(),
        static_cast<const void*>(
            std::string(element.bytes().begin(),
            element.bytes().end()).c_str()));
  } else if (element.type() == net::UploadData::TYPE_FILE) {
    SetToFile(element.file_path().value());
  } else {
    NOTREACHED();
  }
}

void CefPostDataElementImpl::Get(net::UploadData::Element& element) {
  AutoLock lock_scope(this);

  if (type_ == PDE_TYPE_BYTES) {
    element.SetToBytes(static_cast<char*>(data_.bytes.bytes), data_.bytes.size);
  } else if (type_ == PDE_TYPE_FILE) {
    FilePath path = FilePath(CefString(&data_.filename));
    element.SetToFilePath(path);
  } else {
    NOTREACHED();
  }
}

void CefPostDataElementImpl::Set(const WebKit::WebHTTPBody::Element& element) {
  AutoLock lock_scope(this);
  CHECK_READONLY_RETURN_VOID();

  if (element.type == WebKit::WebHTTPBody::Element::TypeData) {
    SetToBytes(element.data.size(),
        static_cast<const void*>(element.data.data()));
  } else if (element.type == WebKit::WebHTTPBody::Element::TypeFile) {
    SetToFile(string16(element.filePath));
  } else {
    NOTREACHED();
  }
}

void CefPostDataElementImpl::Get(WebKit::WebHTTPBody::Element& element) {
  AutoLock lock_scope(this);

  if (type_ == PDE_TYPE_BYTES) {
    element.type = WebKit::WebHTTPBody::Element::TypeData;
    element.data.assign(
        static_cast<char*>(data_.bytes.bytes), data_.bytes.size);
  } else if (type_ == PDE_TYPE_FILE) {
    element.type = WebKit::WebHTTPBody::Element::TypeFile;
    element.filePath.assign(string16(CefString(&data_.filename)));
  } else {
    NOTREACHED();
  }
}

void CefPostDataElementImpl::SetReadOnly(bool read_only) {
  AutoLock lock_scope(this);
  if (read_only_ == read_only)
    return;

  read_only_ = read_only;
}

void CefPostDataElementImpl::Cleanup() {
  if (type_ == PDE_TYPE_EMPTY)
    return;

  if (type_ == PDE_TYPE_BYTES)
    free(data_.bytes.bytes);
  else if (type_ == PDE_TYPE_FILE)
    cef_string_clear(&data_.filename);
  type_ = PDE_TYPE_EMPTY;
  memset(&data_, 0, sizeof(data_));
}
