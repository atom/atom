// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/renderer/frame_impl.h"

#include "libcef/common/cef_messages.h"
#include "libcef/common/http_header_utils.h"
#include "libcef/common/request_impl.h"
#include "libcef/renderer/browser_impl.h"
#include "libcef/renderer/dom_document_impl.h"
#include "libcef/renderer/thread_util.h"
#include "libcef/renderer/v8_impl.h"
#include "libcef/renderer/webkit_glue.h"

#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebData.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebDocument.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebFrame.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebString.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURL.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebView.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebScriptSource.h"
#include "webkit/glue/webkit_glue.h"

using WebKit::WebString;

CefFrameImpl::CefFrameImpl(CefBrowserImpl* browser,
                           WebKit::WebFrame* frame)
  : browser_(browser),
    frame_(frame),
    frame_id_(frame->identifier()) {
}

CefFrameImpl::~CefFrameImpl() {
}

bool CefFrameImpl::IsValid() {
  CEF_REQUIRE_RT_RETURN(false);

  return (frame_ != NULL);
}

void CefFrameImpl::Undo() {
  CEF_REQUIRE_RT_RETURN_VOID();
  if (frame_)
    frame_->executeCommand(WebString::fromUTF8("Undo"));
}

void CefFrameImpl::Redo() {
  CEF_REQUIRE_RT_RETURN_VOID();
  if (frame_)
    frame_->executeCommand(WebString::fromUTF8("Redo"));
}

void CefFrameImpl::Cut() {
  CEF_REQUIRE_RT_RETURN_VOID();
  if (frame_)
    frame_->executeCommand(WebString::fromUTF8("Cut"));
}

void CefFrameImpl::Copy() {
  CEF_REQUIRE_RT_RETURN_VOID();
  if (frame_)
    frame_->executeCommand(WebString::fromUTF8("Copy"));
}

void CefFrameImpl::Paste() {
  CEF_REQUIRE_RT_RETURN_VOID();
  if (frame_)
    frame_->executeCommand(WebString::fromUTF8("Paste"));
}

void CefFrameImpl::Delete() {
  CEF_REQUIRE_RT_RETURN_VOID();
  if (frame_)
    frame_->executeCommand(WebString::fromUTF8("Delete"));
}

void CefFrameImpl::SelectAll() {
  CEF_REQUIRE_RT_RETURN_VOID();
  if (frame_)
    frame_->executeCommand(WebString::fromUTF8("SelectAll"));
}

void CefFrameImpl::ViewSource() {
  NOTREACHED() << "ViewSource cannot be called from the renderer process";
}

void CefFrameImpl::GetSource(CefRefPtr<CefStringVisitor> visitor) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (frame_) {
    CefString content = std::string(frame_->contentAsMarkup().utf8());
    visitor->Visit(content);
  }
}

void CefFrameImpl::GetText(CefRefPtr<CefStringVisitor> visitor) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (frame_) {
    CefString content = webkit_glue::DumpDocumentText(frame_);
    visitor->Visit(content);
  }
}

void CefFrameImpl::LoadRequest(CefRefPtr<CefRequest> request) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (!browser_)
    return;

  CefMsg_LoadRequest_Params params;
  params.url = GURL(std::string(request->GetURL()));
  params.method = request->GetMethod();
  params.frame_id = frame_id_;
  params.first_party_for_cookies =
      GURL(std::string(request->GetFirstPartyForCookies()));

  CefRequest::HeaderMap headerMap;
  request->GetHeaderMap(headerMap);
  if (!headerMap.empty())
    params.headers = HttpHeaderUtils::GenerateHeaders(headerMap);

  CefRefPtr<CefPostData> postData = request->GetPostData();
  if (postData.get()) {
    CefPostDataImpl* impl = static_cast<CefPostDataImpl*>(postData.get());
    params.upload_data = new net::UploadData();
    impl->Get(*params.upload_data.get());
  }

  params.load_flags = request->GetFlags();

  browser_->LoadRequest(params);
}

void CefFrameImpl::LoadURL(const CefString& url) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (!browser_)
    return;

  CefMsg_LoadRequest_Params params;
  params.url = GURL(url.ToString());
  params.method = "GET";
  params.frame_id = frame_id_;
  
  browser_->LoadRequest(params);
}

void CefFrameImpl::LoadString(const CefString& string,
                              const CefString& url) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (frame_) {
    GURL gurl = GURL(url.ToString());
    frame_->loadHTMLString(string.ToString(), gurl);
  }
}

void CefFrameImpl::ExecuteJavaScript(const CefString& jsCode,
                                     const CefString& scriptUrl,
                                     int startLine) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (jsCode.empty())
    return;
  if (startLine < 0)
    startLine = 0;

  if (frame_) {
    GURL gurl = GURL(scriptUrl.ToString());
    frame_->executeScript(
        WebKit::WebScriptSource(jsCode.ToString16(), gurl, startLine));
  }
}

bool CefFrameImpl::IsMain() {
  CEF_REQUIRE_RT_RETURN(false);

  if (frame_)
    return (frame_->parent() == NULL);
  return false;
}

bool CefFrameImpl::IsFocused() {
  CEF_REQUIRE_RT_RETURN(false);

  if (frame_ && frame_->view())
    return (frame_->view()->focusedFrame() == frame_);
  return false;
}

CefString CefFrameImpl::GetName() {
  CefString name;
  CEF_REQUIRE_RT_RETURN(name);

  if (frame_)
    name = frame_->name();
  return name;
}

int64 CefFrameImpl::GetIdentifier() {
  CEF_REQUIRE_RT_RETURN(0);

  return frame_id_;
}

CefRefPtr<CefFrame> CefFrameImpl::GetParent() {
  CEF_REQUIRE_RT_RETURN(NULL);

  if (frame_) {
    WebKit::WebFrame* parent = frame_->parent();
    if (parent)
      return browser_->GetWebFrameImpl(parent).get();
  }

  return NULL;
}

CefString CefFrameImpl::GetURL() {
  CefString url;
  CEF_REQUIRE_RT_RETURN(url);

  if (frame_) {
    GURL gurl = frame_->document().url();
    url = gurl.spec();
  }
  return url;
}

CefRefPtr<CefBrowser> CefFrameImpl::GetBrowser() {
  CEF_REQUIRE_RT_RETURN(NULL);

  return browser_;
}

CefRefPtr<CefV8Context> CefFrameImpl::GetV8Context() {
  CEF_REQUIRE_RT_RETURN(NULL);

  if (frame_) {
    v8::HandleScope handle_scope;
    return new CefV8ContextImpl(webkit_glue::GetV8Context(frame_));
  } else {
    return NULL;
  }
}

void CefFrameImpl::VisitDOM(CefRefPtr<CefDOMVisitor> visitor) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (!frame_)
    return;

  // Create a CefDOMDocumentImpl object that is valid only for the scope of this
  // method.
  CefRefPtr<CefDOMDocumentImpl> documentImpl;
  const WebKit::WebDocument& document = frame_->document();
  if (!document.isNull())
    documentImpl = new CefDOMDocumentImpl(browser_, frame_);

  visitor->Visit(documentImpl.get());

  if (documentImpl.get())
    documentImpl->Detach();
}

void CefFrameImpl::Detach() {
  browser_ = NULL;
  frame_ = NULL;
}
