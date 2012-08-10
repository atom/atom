// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/browser_urlrequest_impl.h"

#include <string>

#include "libcef/browser/browser_context.h"
#include "libcef/browser/context.h"
#include "libcef/browser/thread_util.h"
#include "libcef/common/http_header_utils.h"
#include "libcef/common/request_impl.h"
#include "libcef/common/response_impl.h"

#include "base/logging.h"
#include "base/message_loop.h"
#include "base/string_util.h"
#include "content/public/common/url_fetcher.h"
#include "net/base/load_flags.h"
#include "net/http/http_response_headers.h"
#include "net/url_request/url_fetcher_delegate.h"
#include "net/url_request/url_request_status.h"


namespace {

class CefURLFetcherDelegate : public net::URLFetcherDelegate {
 public:
  CefURLFetcherDelegate(CefBrowserURLRequest::Context* context,
                        int request_flags);
  virtual ~CefURLFetcherDelegate();

  // net::URLFetcherDelegate methods.
  virtual void OnURLFetchComplete(const net::URLFetcher* source) OVERRIDE;
  virtual void OnURLFetchDownloadProgress(const net::URLFetcher* source,
                                          int64 current, int64 total) OVERRIDE;
  virtual void OnURLFetchDownloadData(const net::URLFetcher* source,
                                      scoped_ptr<std::string> download_data)
                                      OVERRIDE;
  virtual bool ShouldSendDownloadData() OVERRIDE;
  virtual void OnURLFetchUploadProgress(const net::URLFetcher* source,
                                        int64 current, int64 total) OVERRIDE;

 private:
  // The context_ pointer will outlive this object.
  CefBrowserURLRequest::Context* context_;
  int request_flags_;
};

}  // namespace


// CefBrowserURLRequest::Context ----------------------------------------------

class CefBrowserURLRequest::Context
    : public base::RefCountedThreadSafe<CefBrowserURLRequest::Context> {
 public:
  Context(CefRefPtr<CefBrowserURLRequest> url_request,
          CefRefPtr<CefRequest> request,
          CefRefPtr<CefURLRequestClient> client)
    : url_request_(url_request),
      request_(request),
      client_(client),
      message_loop_proxy_(MessageLoop::current()->message_loop_proxy()),
    status_(UR_IO_PENDING),
    error_code_(ERR_NONE),
    upload_data_size_(0),
    got_upload_progress_complete_(false) {
    // Mark the request as read-only.
    static_cast<CefRequestImpl*>(request_.get())->SetReadOnly(true);
  }

  virtual ~Context() {
    if (fetcher_.get()) {
      // Delete the fetcher object on the thread that created it.
      message_loop_proxy_->DeleteSoon(FROM_HERE, fetcher_.release());
    }
  }

  inline bool CalledOnValidThread() {
    return message_loop_proxy_->BelongsToCurrentThread();
  }

  bool Start() {
    DCHECK(CalledOnValidThread());

    GURL url = GURL(request_->GetURL().ToString());
    if (!url.is_valid())
      return false;

    std::string method = request_->GetMethod();
    StringToLowerASCII(&method);
    net::URLFetcher::RequestType request_type = net::URLFetcher::GET;
    if (LowerCaseEqualsASCII(method, "get")) {
    } else if (LowerCaseEqualsASCII(method, "post")) {
      request_type = net::URLFetcher::POST;
    } else if (LowerCaseEqualsASCII(method, "head")) {
      request_type = net::URLFetcher::HEAD;
    } else if (LowerCaseEqualsASCII(method, "delete")) {
      request_type = net::URLFetcher::DELETE_REQUEST;
    } else if (LowerCaseEqualsASCII(method, "put")) {
      request_type = net::URLFetcher::PUT;
    } else {
      NOTREACHED() << "invalid request type";
      return false;
    }

    fetcher_delegate_.reset(
        new CefURLFetcherDelegate(this, request_->GetFlags()));

    fetcher_.reset(content::URLFetcher::Create(url, request_type,
                                               fetcher_delegate_.get()));
    fetcher_->SetRequestContext(
        _Context->browser_context()->GetRequestContext());

    CefRequest::HeaderMap headerMap;
    request_->GetHeaderMap(headerMap);

    // Extract the Referer header value.
    {
      CefString referrerStr;
      referrerStr.FromASCII(net::HttpRequestHeaders::kReferer);
      CefRequest::HeaderMap::iterator it = headerMap.find(referrerStr);
      if (it == headerMap.end()) {
        fetcher_->SetReferrer("");
      } else {
        fetcher_->SetReferrer(it->second);
        headerMap.erase(it);
      }
    }

    std::string content_type;

    // Extract the Content-Type header value.
    {
      CefString contentTypeStr;
      contentTypeStr.FromASCII(net::HttpRequestHeaders::kContentType);
      CefRequest::HeaderMap::iterator it = headerMap.find(contentTypeStr);
      if (it != headerMap.end()) {
        content_type = it->second;
        headerMap.erase(it);
      }
    }

    int64 upload_data_size = 0;

    CefRefPtr<CefPostData> post_data = request_->GetPostData();
    if (post_data.get()) {
      CefPostData::ElementVector elements;
      post_data->GetElements(elements);
      if (elements.size() == 1 && elements[0]->GetType() == PDE_TYPE_BYTES) {
        CefPostDataElementImpl* impl =
            static_cast<CefPostDataElementImpl*>(elements[0].get());

        // Default to URL encoding if not specified.
        if (content_type.empty())
          content_type = "application/x-www-form-urlencoded";

        upload_data_size = impl->GetBytesCount();
        fetcher_->SetUploadData(content_type,
            std::string(static_cast<char*>(impl->GetBytes()),
                        upload_data_size));
      } else {
        NOTIMPLEMENTED() << "multi-part form data is not supported";
      }
    }

    std::string first_party_for_cookies = request_->GetFirstPartyForCookies();
    if (!first_party_for_cookies.empty())
      fetcher_->SetFirstPartyForCookies(GURL(first_party_for_cookies));

    int cef_flags = request_->GetFlags();

    if (cef_flags & UR_FLAG_NO_RETRY_ON_5XX)
      fetcher_->SetAutomaticallyRetryOn5xx(false);

    int load_flags = 0;

    if (cef_flags & UR_FLAG_SKIP_CACHE)
      load_flags |= net::LOAD_BYPASS_CACHE;

    if (cef_flags & UR_FLAG_ALLOW_CACHED_CREDENTIALS) {
      if (!(cef_flags & UR_FLAG_ALLOW_COOKIES)) {
        load_flags |= net::LOAD_DO_NOT_SEND_COOKIES;
        load_flags |= net::LOAD_DO_NOT_SAVE_COOKIES;
      }
    } else {
      load_flags |= net::LOAD_DO_NOT_SEND_AUTH_DATA;
      load_flags |= net::LOAD_DO_NOT_SEND_COOKIES;
      load_flags |= net::LOAD_DO_NOT_SAVE_COOKIES;
    }

    if (cef_flags & UR_FLAG_REPORT_UPLOAD_PROGRESS) {
      load_flags |= net::LOAD_ENABLE_UPLOAD_PROGRESS;
      upload_data_size_ = upload_data_size;
    }

    if (cef_flags & UR_FLAG_REPORT_LOAD_TIMING)
      load_flags |= net::LOAD_ENABLE_LOAD_TIMING;

    if (cef_flags & UR_FLAG_REPORT_RAW_HEADERS)
      load_flags |= net::LOAD_REPORT_RAW_HEADERS;

    fetcher_->SetLoadFlags(load_flags);

    fetcher_->SetExtraRequestHeaders(
        HttpHeaderUtils::GenerateHeaders(headerMap));

    fetcher_->Start();

    return true;
  }

  void Cancel() {
    DCHECK(CalledOnValidThread());

    // The request may already be complete.
    if (!fetcher_.get())
      return;

    // Cancel the fetch by deleting the fetcher.
    fetcher_.reset(NULL);

    status_ = UR_CANCELED;
    error_code_ = ERR_ABORTED;
    OnComplete();
  }

  void OnComplete() {
    DCHECK(CalledOnValidThread());

    if (fetcher_.get()) {
      const net::URLRequestStatus& status = fetcher_->GetStatus();

      if (status.is_success())
        NotifyUploadProgressIfNecessary();

      switch (status.status()) {
        case net::URLRequestStatus::SUCCESS:
          status_ = UR_SUCCESS;
          break;
        case net::URLRequestStatus::IO_PENDING:
          status_ = UR_IO_PENDING;
          break;
        case net::URLRequestStatus::HANDLED_EXTERNALLY:
          status_ = UR_HANDLED_EXTERNALLY;
          break;
        case net::URLRequestStatus::CANCELED:
          status_ = UR_CANCELED;
          break;
        case net::URLRequestStatus::FAILED:
          status_ = UR_FAILED;
          break;
      }

      error_code_ = static_cast<CefURLRequest::ErrorCode>(status.error());

      response_ = new CefResponseImpl();
      CefResponseImpl* responseImpl =
          static_cast<CefResponseImpl*>(response_.get());

      net::HttpResponseHeaders* headers = fetcher_->GetResponseHeaders();
      if (headers)
        responseImpl->SetResponseHeaders(*headers);

      responseImpl->SetReadOnly(true);
    }

    DCHECK(url_request_.get());
    client_->OnRequestComplete(url_request_.get());

    if (fetcher_.get())
      fetcher_.reset(NULL);

    // This may result in the Context object being deleted.
    url_request_ = NULL;
  }

  void OnDownloadProgress(int64 current, int64 total) {
    DCHECK(CalledOnValidThread());
    DCHECK(url_request_.get());

    NotifyUploadProgressIfNecessary();

    client_->OnDownloadProgress(url_request_.get(), current, total);
  }

  void OnDownloadData(scoped_ptr<std::string> download_data) {
    DCHECK(CalledOnValidThread());
    DCHECK(url_request_.get());
    client_->OnDownloadData(url_request_.get(), download_data->c_str(),
        download_data->length());
  }

  void OnUploadProgress(int64 current, int64 total) {
    DCHECK(CalledOnValidThread());
    DCHECK(url_request_.get());
    if (current == total)
      got_upload_progress_complete_ = true;
    client_->OnUploadProgress(url_request_.get(), current, total);
  }

  CefRefPtr<CefRequest> request() { return request_; }
  CefRefPtr<CefURLRequestClient> client() { return client_; }
  CefURLRequest::Status status() { return status_; }
  CefURLRequest::ErrorCode error_code() { return error_code_; }
  CefRefPtr<CefResponse> response() { return response_; }

 private:
  void NotifyUploadProgressIfNecessary() {
    if (!got_upload_progress_complete_ && upload_data_size_ > 0) {
      // URLFetcher sends upload notifications using a timer and will not send
      // a notification if the request completes too quickly. We therefore
      // send the notification here if necessary.
      client_->OnUploadProgress(url_request_.get(), upload_data_size_,
                                upload_data_size_);
      got_upload_progress_complete_ = true;
    }
  }

  // Members only accessed on the initialization thread.
  CefRefPtr<CefBrowserURLRequest> url_request_;
  CefRefPtr<CefRequest> request_;
  CefRefPtr<CefURLRequestClient> client_;
  scoped_refptr<base::MessageLoopProxy> message_loop_proxy_;
  scoped_ptr<net::URLFetcher> fetcher_;
  scoped_ptr<CefURLFetcherDelegate> fetcher_delegate_;
  CefURLRequest::Status status_;
  CefURLRequest::ErrorCode error_code_;
  CefRefPtr<CefResponse> response_;
  int64 upload_data_size_;
  bool got_upload_progress_complete_;
};


// CefURLFetcherDelegate ------------------------------------------------------

namespace {

CefURLFetcherDelegate::CefURLFetcherDelegate(
    CefBrowserURLRequest::Context* context, int request_flags)
  : context_(context),
    request_flags_(request_flags) {
}

CefURLFetcherDelegate::~CefURLFetcherDelegate() {
}

void CefURLFetcherDelegate::OnURLFetchComplete(
    const net::URLFetcher* source) {
  context_->OnComplete();
}

void CefURLFetcherDelegate::OnURLFetchDownloadProgress(
    const net::URLFetcher* source,
    int64 current, int64 total) {
  context_->OnDownloadProgress(current, total);
}

void CefURLFetcherDelegate::OnURLFetchDownloadData(
    const net::URLFetcher* source,
    scoped_ptr<std::string> download_data) {
  context_->OnDownloadData(download_data.Pass());
}

bool CefURLFetcherDelegate::ShouldSendDownloadData() {
  return !(request_flags_ & UR_FLAG_NO_DOWNLOAD_DATA);
}

void CefURLFetcherDelegate::OnURLFetchUploadProgress(
    const net::URLFetcher* source,
    int64 current, int64 total) {
  if (request_flags_ & UR_FLAG_REPORT_UPLOAD_PROGRESS)
    context_->OnUploadProgress(current, total);
}

}  // namespace


// CefBrowserURLRequest -------------------------------------------------------

CefBrowserURLRequest::CefBrowserURLRequest(
    CefRefPtr<CefRequest> request,
    CefRefPtr<CefURLRequestClient> client) {
  context_ = new Context(this, request, client);
}

CefBrowserURLRequest::~CefBrowserURLRequest() {
}

bool CefBrowserURLRequest::Start() {
  if (!VerifyContext())
    return false;
  return context_->Start();
}

CefRefPtr<CefRequest> CefBrowserURLRequest::GetRequest() {
  if (!VerifyContext())
    return NULL;
  return context_->request();
}

CefRefPtr<CefURLRequestClient> CefBrowserURLRequest::GetClient() {
  if (!VerifyContext())
    return NULL;
  return context_->client();
}

CefURLRequest::Status CefBrowserURLRequest::GetRequestStatus() {
  if (!VerifyContext())
    return UR_UNKNOWN;
  return context_->status();
}

CefURLRequest::ErrorCode CefBrowserURLRequest::GetRequestError() {
  if (!VerifyContext())
    return ERR_NONE;
  return context_->error_code();
}

CefRefPtr<CefResponse> CefBrowserURLRequest::GetResponse() {
  if (!VerifyContext())
    return NULL;
  return context_->response();
}

void CefBrowserURLRequest::Cancel() {
  if (!VerifyContext())
    return;
  return context_->Cancel();
}

bool CefBrowserURLRequest::VerifyContext() {
  DCHECK(context_.get());
  if (!context_->CalledOnValidThread()) {
    NOTREACHED() << "called on invalid thread";
    return false;
  }

  return true;
}
