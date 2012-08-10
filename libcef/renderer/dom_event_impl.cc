// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/renderer/dom_event_impl.h"
#include "libcef/renderer/dom_document_impl.h"
#include "libcef/renderer/thread_util.h"

#include "base/logging.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebDOMEvent.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebString.h"

using WebKit::WebDOMEvent;
using WebKit::WebString;


CefDOMEventImpl::CefDOMEventImpl(CefRefPtr<CefDOMDocumentImpl> document,
                                 const WebKit::WebDOMEvent& event)
    : document_(document),
      event_(event) {
  DCHECK(!event_.isNull());
}

CefDOMEventImpl::~CefDOMEventImpl() {
  CEF_REQUIRE_RT();
  DCHECK(event_.isNull());
}

CefString CefDOMEventImpl::GetType() {
  CefString str;
  if (!VerifyContext())
    return str;

  const WebString& type = event_.type();
  if (!type.isNull())
    str = type;

  return str;
}

CefDOMEventImpl::Category CefDOMEventImpl::GetCategory() {
  if (!VerifyContext())
    return DOM_EVENT_CATEGORY_UNKNOWN;

  int flags = 0;
  if (event_.isUIEvent())
    flags |= DOM_EVENT_CATEGORY_UI;
  if (event_.isMouseEvent())
    flags |= DOM_EVENT_CATEGORY_MOUSE;
  if (event_.isMutationEvent())
    flags |= DOM_EVENT_CATEGORY_MUTATION;
  if (event_.isKeyboardEvent())
    flags |= DOM_EVENT_CATEGORY_KEYBOARD;
  if (event_.isTextEvent())
    flags |= DOM_EVENT_CATEGORY_TEXT;
  if (event_.isCompositionEvent())
    flags |= DOM_EVENT_CATEGORY_COMPOSITION;
  if (event_.isDragEvent())
    flags |= DOM_EVENT_CATEGORY_DRAG;
  if (event_.isClipboardEvent())
    flags |= DOM_EVENT_CATEGORY_CLIPBOARD;
  if (event_.isMessageEvent())
    flags |= DOM_EVENT_CATEGORY_MESSAGE;
  if (event_.isWheelEvent())
    flags |= DOM_EVENT_CATEGORY_WHEEL;
  if (event_.isBeforeTextInsertedEvent())
    flags |= DOM_EVENT_CATEGORY_BEFORE_TEXT_INSERTED;
  if (event_.isOverflowEvent())
    flags |= DOM_EVENT_CATEGORY_OVERFLOW;
  if (event_.isPageTransitionEvent())
    flags |= DOM_EVENT_CATEGORY_PAGE_TRANSITION;
  if (event_.isPopStateEvent())
    flags |= DOM_EVENT_CATEGORY_POPSTATE;
  if (event_.isProgressEvent())
    flags |= DOM_EVENT_CATEGORY_PROGRESS;
  if (event_.isXMLHttpRequestProgressEvent())
    flags |= DOM_EVENT_CATEGORY_XMLHTTPREQUEST_PROGRESS;
  if (event_.isWebKitAnimationEvent())
    flags |= DOM_EVENT_CATEGORY_WEBKIT_ANIMATION;
  if (event_.isWebKitTransitionEvent())
    flags |= DOM_EVENT_CATEGORY_WEBKIT_TRANSITION;
  if (event_.isBeforeLoadEvent())
    flags |= DOM_EVENT_CATEGORY_BEFORE_LOAD;

  return static_cast<Category>(flags);
}

CefDOMEventImpl::Phase CefDOMEventImpl::GetPhase() {
  if (!VerifyContext())
    return DOM_EVENT_PHASE_UNKNOWN;

  switch (event_.eventPhase()) {
    case WebDOMEvent::CapturingPhase:
      return DOM_EVENT_PHASE_CAPTURING;
    case WebDOMEvent::AtTarget:
      return DOM_EVENT_PHASE_AT_TARGET;
    case WebDOMEvent::BubblingPhase:
      return DOM_EVENT_PHASE_BUBBLING;
  }

  return DOM_EVENT_PHASE_UNKNOWN;
}

bool CefDOMEventImpl::CanBubble() {
  if (!VerifyContext())
    return false;

  return event_.bubbles();
}

bool CefDOMEventImpl::CanCancel() {
  if (!VerifyContext())
    return false;

  return event_.cancelable();
}

CefRefPtr<CefDOMDocument> CefDOMEventImpl::GetDocument() {
  if (!VerifyContext())
    return NULL;

  return document_.get();
}

CefRefPtr<CefDOMNode> CefDOMEventImpl::GetTarget() {
  if (!VerifyContext())
    return NULL;

  return document_->GetOrCreateNode(event_.target());
}

CefRefPtr<CefDOMNode> CefDOMEventImpl::GetCurrentTarget() {
  if (!VerifyContext())
    return NULL;

  return document_->GetOrCreateNode(event_.currentTarget());
}

void CefDOMEventImpl::Detach() {
  // If you hit this assert it means that you are keeping references to this
  // event object beyond the valid scope.
  DCHECK_EQ(GetRefCt(), 1);

  document_ = NULL;
  event_.assign(WebDOMEvent());
}

bool CefDOMEventImpl::VerifyContext() {
  if (!document_.get()) {
    NOTREACHED();
    return false;
  }
  if (!document_->VerifyContext())
    return false;
  if (event_.isNull()) {
    NOTREACHED();
    return false;
  }
  return true;
}
