// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_UNITTESTS_TEST_SUITE_H_
#define CEF_TESTS_UNITTESTS_TEST_SUITE_H_
#pragma once

#include <string>
#include "include/internal/cef_types_wrappers.h"
#include "base/test/test_suite.h"

class CommandLine;

class CefTestSuite : public TestSuite {
 public:
  CefTestSuite(int argc, char** argv);

  // Initialize the current process CommandLine singleton. On Windows, ignores
  // its arguments (we instead parse GetCommandLineW() directly) because we
  // don't trust the CRT's parsing of the command line, but it still must be
  // called to set up the command line.
  static void InitCommandLine(int argc, const char* const* argv);

  static void GetSettings(CefSettings& settings);
  static bool GetCachePath(std::string& path);

 protected:
#if defined(OS_MACOSX)
  virtual void Initialize();
#endif

  // The singleton CommandLine representing the current process's command line.
  static CommandLine* commandline_;
};

#endif  // CEF_TESTS_UNITTESTS_TEST_SUITE_H_
