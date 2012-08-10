// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/frame_host_impl.h"
#include "include/cef_request.h"
#include "include/cef_stream.h"
#include "include/cef_v8.h"
#include "libcef/common/cef_messages.h"
#include "libcef/browser/browser_host_impl.h"

namespace {

// Implementation of CommandResponseHandler for calling a CefStringVisitor.
class StringVisitHandler : public CefResponseManager::Handler {
 public:
  explicit StringVisitHandler(CefRefPtr<CefStringVisitor> visitor)
      : visitor_(visitor) {
  }
  virtual void OnResponse(const Cef_Response_Params& params) OVERRIDE {
    visitor_->Visit(params.response);
  }
 private:
  CefRefPtr<CefStringVisitor> visitor_;

  IMPLEMENT_REFCOUNTING(StringVisitHandler);
};

// Implementation of CommandResponseHandler for calling ViewText().
class ViewTextHandler : public CefResponseManager::Handler {
 public:
  explicit ViewTextHandler(CefRefPtr<CefFrameHostImpl> frame)
      : frame_(frame) {
  }
  virtual void OnResponse(const Cef_Response_Params& params) OVERRIDE {
    CefRefPtr<CefBrowser> browser = frame_->GetBrowser();
    if (browser.get()) {
      static_cast<CefBrowserHostImpl*>(browser.get())->ViewText(
          params.response);
    }
  }
 private:
  CefRefPtr<CefFrameHostImpl> frame_;

  IMPLEMENT_REFCOUNTING(ViewTextHandler);
};

}  // namespace

CefFrameHostImpl::CefFrameHostImpl(CefBrowserHostImpl* browser,
                                   int64 frame_id,
                                   bool is_main_frame)
    : frame_id_(frame_id),
      is_main_frame_(is_main_frame),
      browser_(browser),
      is_focused_(false),
      parent_frame_id_(kInvalidFrameId) {
}

CefFrameHostImpl::~CefFrameHostImpl() {
}

bool CefFrameHostImpl::IsValid() {
  base::AutoLock lock_scope(state_lock_);
  return (browser_ != NULL);
}

void CefFrameHostImpl::Undo() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "Undo", NULL);
}

void CefFrameHostImpl::Redo() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "Redo", NULL);
}

void CefFrameHostImpl::Cut() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "Cut", NULL);
}

void CefFrameHostImpl::Copy() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "Copy", NULL);
}

void CefFrameHostImpl::Paste() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "Paste", NULL);
}

void CefFrameHostImpl::Delete() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "Delete", NULL);
}

void CefFrameHostImpl::SelectAll() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "SelectAll", NULL);
}

void CefFrameHostImpl::ViewSource() {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId)
    browser_->SendCommand(frame_id_, "GetSource", new ViewTextHandler(this));
}

void CefFrameHostImpl::GetSource(CefRefPtr<CefStringVisitor> visitor) {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId) {
    browser_->SendCommand(frame_id_, "GetSource",
                          new StringVisitHandler(visitor));
  }
}

void CefFrameHostImpl::GetText(CefRefPtr<CefStringVisitor> visitor) {
  base::AutoLock lock_scope(state_lock_);
  if (browser_ && frame_id_ != kInvalidFrameId) {
    browser_->SendCommand(frame_id_, "GetText",
                          new StringVisitHandler(visitor));
  }
}

void CefFrameHostImpl::LoadRequest(CefRefPtr<CefRequest> request) {
  base::AutoLock lock_scope(state_lock_);
  if (browser_)
    browser_->LoadRequest((is_main_frame_ ? kMainFrameId : frame_id_), request);
}

void CefFrameHostImpl::LoadURL(const CefString& url) {
  base::AutoLock lock_scope(state_lock_);
  if (browser_)
    browser_->LoadURL((is_main_frame_ ? kMainFrameId : frame_id_), url);
}

void CefFrameHostImpl::LoadString(const CefString& string,
                                  const CefString& url) {
  base::AutoLock lock_scope(state_lock_);
  if (browser_) {
    browser_->LoadString((is_main_frame_ ? kMainFrameId : frame_id_), string,
                         url);
  }
}

void CefFrameHostImpl::ExecuteJavaScript(const CefString& jsCode,
                                         const CefString& scriptUrl,
                                         int startLine) {
  if (jsCode.empty())
    return;
  if (startLine < 0)
    startLine = 0;

  base::AutoLock lock_scope(state_lock_);
  if (browser_) {
    browser_->SendCode((is_main_frame_ ? kMainFrameId : frame_id_), true,
                       jsCode, scriptUrl, startLine, NULL);
  }
}

bool CefFrameHostImpl::IsMain() {
  return is_main_frame_;
}

bool CefFrameHostImpl::IsFocused() {
  base::AutoLock lock_scope(state_lock_);
  return is_focused_;
}

CefString CefFrameHostImpl::GetName() {
  base::AutoLock lock_scope(state_lock_);
  return name_;
}

int64 CefFrameHostImpl::GetIdentifier() {
  return frame_id_;
}

CefRefPtr<CefFrame> CefFrameHostImpl::GetParent() {
  base::AutoLock lock_scope(state_lock_);

  if (is_main_frame_ || parent_frame_id_ == kInvalidFrameId)
    return NULL;

  if (browser_)
    return browser_->GetFrame(parent_frame_id_);

  return NULL;
}

CefString CefFrameHostImpl::GetURL() {
  base::AutoLock lock_scope(state_lock_);
  return url_;
}

CefRefPtr<CefBrowser> CefFrameHostImpl::GetBrowser() {
  base::AutoLock lock_scope(state_lock_);
  return browser_;
}

void CefFrameHostImpl::SetFocused(bool focused) {
  base::AutoLock lock_scope(state_lock_);
  is_focused_ = focused;
}

void CefFrameHostImpl::SetURL(const CefString& url) {
  base::AutoLock lock_scope(state_lock_);
  url_ = url;
}

void CefFrameHostImpl::SetName(const CefString& name) {
  base::AutoLock lock_scope(state_lock_);
  name_ = name;
}

void CefFrameHostImpl::SetParentId(int64 frame_id) {
  base::AutoLock lock_scope(state_lock_);
  parent_frame_id_ = frame_id;
}

CefRefPtr<CefV8Context> CefFrameHostImpl::GetV8Context() {
  NOTREACHED() << "GetV8Context cannot be called from the browser process";
  return NULL;
}

void CefFrameHostImpl::VisitDOM(CefRefPtr<CefDOMVisitor> visitor) {
  NOTREACHED() << "VisitDOM cannot be called from the browser process";
}

void CefFrameHostImpl::Detach() {
  base::AutoLock lock_scope(state_lock_);
  browser_ = NULL;
}
