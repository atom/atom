// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_DOM_TEST_H_
#define CEF_TESTS_CEFCLIENT_DOM_TEST_H_
#pragma once

#include "include/cef_base.h"
#include "cefclient/client_app.h"

namespace dom_test {

// The DOM test URL.
extern const char kTestUrl[];

// Create the render delegate.
void CreateRenderDelegates(ClientApp::RenderDelegateSet& delegates);

// Run the test.
void RunTest(CefRefPtr<CefBrowser> browser);

// Continue the test after the page has loaded.
void OnLoadEnd(CefRefPtr<CefBrowser> browser);

}  // namespace dom_test

#endif  // CEF_TESTS_CEFCLIENT_DOM_TEST_H_
