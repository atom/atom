// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/renderer/webkit_glue.h"

#include "base/compiler_specific.h"

#include "third_party/WebKit/Source/WebCore/config.h"
MSVC_PUSH_WARNING_LEVEL(0);
#include "Page.h"
#include "third_party/WebKit/Source/WebKit/chromium/src/WebFrameImpl.h"
#include "third_party/WebKit/Source/WebKit/chromium/src/WebViewImpl.h"
MSVC_POP_WARNING();
#undef LOG

namespace webkit_glue {

bool CanGoBackOrForward(WebKit::WebView* view, int distance) {
  if (!view)
    return false;
  WebKit::WebViewImpl* impl = reinterpret_cast<WebKit::WebViewImpl*>(view);
  return impl->page()->canGoBackOrForward(distance);
}

void GoBackOrForward(WebKit::WebView* view, int distance) {
  if (!view)
    return;
  WebKit::WebViewImpl* impl = reinterpret_cast<WebKit::WebViewImpl*>(view);
  impl->page()->goBackOrForward(distance);
}

v8::Handle<v8::Context> GetV8Context(WebKit::WebFrame* frame) {
  WebKit::WebFrameImpl* impl = static_cast<WebKit::WebFrameImpl*>(frame);
  WebCore::Frame* core_frame = impl->frame();
  return WebCore::V8Proxy::context(core_frame);
}

}  // webkit_glue
