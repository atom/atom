// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/renderer/render_urlrequest_impl.h"
#include "libcef/common/request_impl.h"
#include "libcef/common/response_impl.h"

#include "base/logging.h"
#include "base/message_loop.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebKitPlatformSupport.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebString.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURL.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURLError.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURLLoader.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURLLoaderClient.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURLRequest.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURLResponse.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebKit.h"

using WebKit::WebString;
using WebKit::WebURL;
using WebKit::WebURLError;
using WebKit::WebURLLoader;
using WebKit::WebURLRequest;
using WebKit::WebURLResponse;


namespace {

class CefWebURLLoaderClient : public WebKit::WebURLLoaderClient {
 public:
  CefWebURLLoaderClient(CefRenderURLRequest::Context* context,
                        int request_flags);
  virtual ~CefWebURLLoaderClient();

  // WebKit::WebURLLoaderClient methods.
  virtual void willSendRequest(
      WebURLLoader* loader,
      WebURLRequest& newRequest,
      const WebURLResponse& redirectResponse) OVERRIDE;
  virtual void didSendData(
      WebURLLoader* loader,
      unsigned long long bytesSent,
      unsigned long long totalBytesToBeSent) OVERRIDE;
  virtual void didReceiveResponse(
      WebURLLoader* loader,
      const WebURLResponse& response) OVERRIDE;
  virtual void didDownloadData(WebURLLoader* loader,
                               int dataLength) OVERRIDE;
  virtual void didReceiveData(WebURLLoader* loader,
                              const char* data,
                              int dataLength,
                              int encodedDataLength) OVERRIDE;
  virtual void didReceiveCachedMetadata(WebURLLoader* loader,
                                        const char* data,
                                        int dataLength) OVERRIDE;
  virtual void didFinishLoading(WebURLLoader* loader,
                                double finishTime) OVERRIDE;
  virtual void didFail(WebURLLoader* loader,
                       const WebURLError& error) OVERRIDE;

 protected:
  // The context_ pointer will outlive this object.
  CefRenderURLRequest::Context* context_;
  int request_flags_;
};

}  // namespace


// CefRenderURLRequest::Context -----------------------------------------------

class CefRenderURLRequest::Context
    : public base::RefCountedThreadSafe<CefRenderURLRequest::Context> {
 public:
  Context(CefRefPtr<CefRenderURLRequest> url_request,
          CefRefPtr<CefRequest> request,
          CefRefPtr<CefURLRequestClient> client)
    : url_request_(url_request),
      request_(request),
      client_(client),
      message_loop_proxy_(MessageLoop::current()->message_loop_proxy()),
      status_(UR_IO_PENDING),
      error_code_(ERR_NONE),
      upload_data_size_(0),
      got_upload_progress_complete_(false),
      download_data_received_(0),
      download_data_total_(-1) {
    // Mark the request as read-only.
    static_cast<CefRequestImpl*>(request_.get())->SetReadOnly(true);
  }

  virtual ~Context() {
  }

  inline bool CalledOnValidThread() {
    return message_loop_proxy_->BelongsToCurrentThread();
  }

  bool Start() {
    DCHECK(CalledOnValidThread());

    GURL url = GURL(request_->GetURL().ToString());
    if (!url.is_valid())
      return false;

    loader_.reset(WebKit::webKitPlatformSupport()->createURLLoader());
    url_client_.reset(new CefWebURLLoaderClient(this, request_->GetFlags()));

    WebURLRequest urlRequest;
    static_cast<CefRequestImpl*>(request_.get())->Get(urlRequest);

    if (urlRequest.reportUploadProgress()) {
      // Attempt to determine the upload data size.
      CefRefPtr<CefPostData> post_data = request_->GetPostData();
      if (post_data.get()) {
        CefPostData::ElementVector elements;
        post_data->GetElements(elements);
        if (elements.size() == 1 && elements[0]->GetType() == PDE_TYPE_BYTES) {
          CefPostDataElementImpl* impl =
              static_cast<CefPostDataElementImpl*>(elements[0].get());
          upload_data_size_ = impl->GetBytesCount();
        }
      }
    }

    loader_->loadAsynchronously(urlRequest, url_client_.get());
    return true;
  }

  void Cancel() {
    DCHECK(CalledOnValidThread());

    // The request may already be complete.
    if (!loader_.get() || status_ != UR_IO_PENDING)
      return;

    status_ = UR_CANCELED;
    error_code_ = ERR_ABORTED;

    // Will result in a call to OnError().
    loader_->cancel();
  }

  void OnResponse(const WebURLResponse& response) {
    DCHECK(CalledOnValidThread());

    response_ = CefResponse::Create();
    CefResponseImpl* responseImpl =
        static_cast<CefResponseImpl*>(response_.get());
    responseImpl->Set(response);
    responseImpl->SetReadOnly(true);

    download_data_total_ = response.expectedContentLength();
  }

  void OnError(const WebURLError& error) {
    DCHECK(CalledOnValidThread());

    if (status_ == UR_IO_PENDING) {
      status_ = UR_FAILED;
      error_code_ = static_cast<CefURLRequest::ErrorCode>(error.reason);
    }

    OnComplete();
  }

  void OnComplete() {
    DCHECK(CalledOnValidThread());

    if (status_ == UR_IO_PENDING) {
      status_ = UR_SUCCESS;
      NotifyUploadProgressIfNecessary();
    }

    if (loader_.get())
      loader_.reset(NULL);

    DCHECK(url_request_.get());
    client_->OnRequestComplete(url_request_.get());

    // This may result in the Context object being deleted.
    url_request_ = NULL;
  }

  void OnDownloadProgress(int64 current) {
    DCHECK(CalledOnValidThread());
    DCHECK(url_request_.get());

    NotifyUploadProgressIfNecessary();

    download_data_received_ += current;
    client_->OnDownloadProgress(url_request_.get(), download_data_received_,
        download_data_total_);
  }

  void OnDownloadData(const char* data, int dataLength) {
    DCHECK(CalledOnValidThread());
    DCHECK(url_request_.get());
    client_->OnDownloadData(url_request_.get(), data, dataLength);
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
  CefRefPtr<CefRenderURLRequest> url_request_;
  CefRefPtr<CefRequest> request_;
  CefRefPtr<CefURLRequestClient> client_;
  scoped_refptr<base::MessageLoopProxy> message_loop_proxy_;
  CefURLRequest::Status status_;
  CefURLRequest::ErrorCode error_code_;
  CefRefPtr<CefResponse> response_;
  scoped_ptr<WebKit::WebURLLoader> loader_;
  scoped_ptr<CefWebURLLoaderClient> url_client_;
  int64 upload_data_size_;
  bool got_upload_progress_complete_;
  int64 download_data_received_;
  int64 download_data_total_;
};


// CefWebURLLoaderClient --------------------------------------------------

namespace {

CefWebURLLoaderClient::CefWebURLLoaderClient(
    CefRenderURLRequest::Context* context,
    int request_flags)
  : context_(context),
    request_flags_(request_flags) {
}

CefWebURLLoaderClient::~CefWebURLLoaderClient() {
}

void CefWebURLLoaderClient::willSendRequest(
    WebURLLoader* loader,
    WebURLRequest& newRequest,
    const WebURLResponse& redirectResponse) {
}

void CefWebURLLoaderClient::didSendData(
    WebURLLoader* loader,
    unsigned long long bytesSent,
    unsigned long long totalBytesToBeSent) {
  if (request_flags_ & UR_FLAG_REPORT_UPLOAD_PROGRESS)
    context_->OnUploadProgress(bytesSent, totalBytesToBeSent);
}

void CefWebURLLoaderClient::didReceiveResponse(
    WebURLLoader* loader,
    const WebURLResponse& response) {
  context_->OnResponse(response);
}

void CefWebURLLoaderClient::didDownloadData(WebURLLoader* loader,
                                            int dataLength) {
}

void CefWebURLLoaderClient::didReceiveData(WebURLLoader* loader,
                                           const char* data,
                                           int dataLength,
                                           int encodedDataLength) {
  context_->OnDownloadProgress(dataLength);

  if (!(request_flags_ & UR_FLAG_NO_DOWNLOAD_DATA))
    context_->OnDownloadData(data, dataLength);
}

void CefWebURLLoaderClient::didReceiveCachedMetadata(WebURLLoader* loader,
                                                     const char* data,
                                                     int dataLength) {
}

void CefWebURLLoaderClient::didFinishLoading(WebURLLoader* loader,
                                             double finishTime) {
  context_->OnComplete();
}

void CefWebURLLoaderClient::didFail(WebURLLoader* loader,
                                    const WebURLError& error) {
  context_->OnError(error);
}


}  // namespace


// CefRenderURLRequest --------------------------------------------------------

CefRenderURLRequest::CefRenderURLRequest(
    CefRefPtr<CefRequest> request,
    CefRefPtr<CefURLRequestClient> client) {
  context_ = new Context(this, request, client);
}

CefRenderURLRequest::~CefRenderURLRequest() {
}

bool CefRenderURLRequest::Start() {
  if (!VerifyContext())
    return false;
  return context_->Start();
}

CefRefPtr<CefRequest> CefRenderURLRequest::GetRequest() {
  if (!VerifyContext())
    return NULL;
  return context_->request();
}

CefRefPtr<CefURLRequestClient> CefRenderURLRequest::GetClient() {
  if (!VerifyContext())
    return NULL;
  return context_->client();
}

CefURLRequest::Status CefRenderURLRequest::GetRequestStatus() {
  if (!VerifyContext())
    return UR_UNKNOWN;
  return context_->status();
}

CefURLRequest::ErrorCode CefRenderURLRequest::GetRequestError() {
  if (!VerifyContext())
    return ERR_NONE;
  return context_->error_code();
}

CefRefPtr<CefResponse> CefRenderURLRequest::GetResponse() {
  if (!VerifyContext())
    return NULL;
  return context_->response();
}

void CefRenderURLRequest::Cancel() {
  if (!VerifyContext())
    return;
  return context_->Cancel();
}

bool CefRenderURLRequest::VerifyContext() {
  DCHECK(context_.get());
  if (!context_->CalledOnValidThread()) {
    NOTREACHED() << "called on invalid thread";
    return false;
  }

  return true;
}
