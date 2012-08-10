// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "tests/unittests/test_suite.h"
#include "tests/cefclient/client_switches.h"
#include "base/command_line.h"
#include "base/logging.h"
#include "base/test/test_suite.h"

#if defined(OS_MACOSX)
#include "base/file_path.h"
#include "base/i18n/icu_util.h"
#include "base/path_service.h"
#include "base/process_util.h"
#include "base/test/test_timeouts.h"
#endif

CommandLine* CefTestSuite::commandline_ = NULL;

CefTestSuite::CefTestSuite(int argc, char** argv)
  : TestSuite(argc, argv) {
}

// static
void CefTestSuite::InitCommandLine(int argc, const char* const* argv) {
  if (commandline_) {
    // If this is intentional, Reset() must be called first. If we are using
    // the shared build mode, we have to share a single object across multiple
    // shared libraries.
    return;
  }

  commandline_ = new CommandLine(CommandLine::NO_PROGRAM);
#if defined(OS_WIN)
  commandline_->ParseFromString(::GetCommandLineW());
#elif defined(OS_POSIX)
  commandline_->InitFromArgv(argc, argv);
#endif
}

// static
void CefTestSuite::GetSettings(CefSettings& settings) {
#if defined(OS_WIN)
  settings.multi_threaded_message_loop =
      commandline_->HasSwitch(cefclient::kMultiThreadedMessageLoop);
#endif

  CefString(&settings.cache_path) =
      commandline_->GetSwitchValueASCII(cefclient::kCachePath);

  // Always expose the V8 gc() function to give tests finer-grained control over
  // memory management.
  std::string javascript_flags = "--expose-gc";
  // Value of kJavascriptFlags switch.
  std::string other_javascript_flags =
      commandline_->GetSwitchValueASCII("js-flags");
  if (!other_javascript_flags.empty())
    javascript_flags += " " + other_javascript_flags;
  CefString(&settings.javascript_flags) = javascript_flags;
}

// static
bool CefTestSuite::GetCachePath(std::string& path) {
  DCHECK(commandline_);

  if (commandline_->HasSwitch(cefclient::kCachePath)) {
    // Set the cache_path value.
    path = commandline_->GetSwitchValueASCII(cefclient::kCachePath);
    return true;
  }

  return false;
}

#if defined(OS_MACOSX)
void CefTestSuite::Initialize() {
  // The below code is copied from base/test/test_suite.cc to avoid calling
  // RegisterMockCrApp() on Mac.

  // Initialize logging.
  FilePath exe;
  PathService::Get(base::FILE_EXE, &exe);
  FilePath log_filename = exe.ReplaceExtension(FILE_PATH_LITERAL("log"));
  logging::InitLogging(
                       log_filename.value().c_str(),
                       logging::LOG_TO_BOTH_FILE_AND_SYSTEM_DEBUG_LOG,
                       logging::LOCK_LOG_FILE,
                       logging::DELETE_OLD_LOG_FILE,
                       logging::DISABLE_DCHECK_FOR_NON_OFFICIAL_RELEASE_BUILDS);
  // We want process and thread IDs because we may have multiple processes.
  // Note: temporarily enabled timestamps in an effort to catch bug 6361.
  logging::SetLogItems(true, true, true, true);

  CHECK(base::EnableInProcessStackDumping());

  // In some cases, we do not want to see standard error dialogs.
  if (!base::debug::BeingDebugged() &&
      !CommandLine::ForCurrentProcess()->HasSwitch("show-error-dialogs")) {
    SuppressErrorDialogs();
    base::debug::SetSuppressDebugUI(true);
    logging::SetLogAssertHandler(UnitTestAssertHandler);
  }

  icu_util::Initialize();

  CatchMaybeTests();
  ResetCommandLine();

  TestTimeouts::Initialize();
}
#endif  // defined(OS_MACOSX)
