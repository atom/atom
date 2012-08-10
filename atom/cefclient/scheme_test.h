// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_SCHEME_TEST_H_
#define CEF_TESTS_CEFCLIENT_SCHEME_TEST_H_
#pragma once

#include <vector>
#include "include/cef_base.h"

class CefBrowser;
class CefSchemeRegistrar;

namespace scheme_test {

// Register the scheme.
void RegisterCustomSchemes(CefRefPtr<CefSchemeRegistrar> registrar,
                           std::vector<CefString>& cookiable_schemes);

// Create the scheme handler.
void InitTest();

// Run the test.
void RunTest(CefRefPtr<CefBrowser> browser);

}  // namespace scheme_test

#endif  // CEF_TESTS_CEFCLIENT_SCHEME_TEST_H_
