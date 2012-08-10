// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_RENDERER_WEBKIT_GLUE_H_
#define CEF_LIBCEF_RENDERER_WEBKIT_GLUE_H_

#include <string>
#include "v8/include/v8.h"

namespace WebKit {
class WebFrame;
class WebView;
}

namespace webkit_glue {

bool CanGoBackOrForward(WebKit::WebView* view, int distance);
void GoBackOrForward(WebKit::WebView* view, int distance);

// Retrieve the V8 context associated with the frame.
v8::Handle<v8::Context> GetV8Context(WebKit::WebFrame* frame);

}  // webkit_glue

#endif  // CEF_LIBCEF_RENDERER_WEBKIT_GLUE_H_
