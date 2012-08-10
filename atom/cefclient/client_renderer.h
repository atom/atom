// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_CLIENT_RENDERER_H_
#define CEF_TESTS_CEFCLIENT_CLIENT_RENDERER_H_
#pragma once

#include "include/cef_base.h"
#include "cefclient/client_app.h"

namespace client_renderer {

// Message sent when the focused node changes.
extern const char kFocusedNodeChangedMessage[];

// Create the render delegate.
void CreateRenderDelegates(ClientApp::RenderDelegateSet& delegates);

}  // namespace client_renderer

#endif  // CEF_TESTS_CEFCLIENT_CLIENT_RENDERER_H_
