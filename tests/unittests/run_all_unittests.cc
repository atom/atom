// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_app.h"
#include "include/cef_task.h"
#include "tests/cefclient/client_app.h"
#include "tests/unittests/test_suite.h"
#include "base/bind.h"
#include "base/command_line.h"
#include "base/threading/thread.h"

// Include after base/bind.h to avoid name collisions with cef_tuple.h.
#include "include/cef_runnable.h"

namespace {

// Thread used to run the test suite.
class CefTestThread : public base::Thread {
 public:
  explicit CefTestThread(CefTestSuite* test_suite)
    : base::Thread("test_thread"),
      test_suite_(test_suite) {
  }

  void RunTests() {
    // Run the test suite.
    retval_ = test_suite_->Run();

    // Quit the CEF message loop.
    CefPostTask(TID_UI, NewCefRunnableFunction(CefQuitMessageLoop));
  }

  int retval() { return retval_; }

 protected:
  CefTestSuite* test_suite_;
  int retval_;
};

// Called on the UI thread.
void RunTests(CefTestThread* thread) {
  // Run the test suite on the test thread.
  thread->message_loop()->PostTask(FROM_HERE,
      base::Bind(&CefTestThread::RunTests, base::Unretained(thread)));
}

}  // namespace


int main(int argc, char* argv[]) {
#if defined(OS_WIN)
  CefMainArgs main_args(::GetModuleHandle(NULL));
#else
  CefMainArgs main_args(argc, argv);
#endif

  CefRefPtr<CefApp> app(new ClientApp);

  // Execute the secondary process, if any.
  int exit_code = CefExecuteProcess(main_args, app);
  if (exit_code >= 0)
    return exit_code;

  // Initialize the CommandLine object.
  CefTestSuite::InitCommandLine(argc, argv);

  CefSettings settings;
  CefTestSuite::GetSettings(settings);

#if defined(OS_MACOSX)
  // Platform-specific initialization.
  extern void PlatformInit();
  PlatformInit();
#endif

  // Initialize CEF.
  CefInitialize(main_args, settings, app);

  // Create the test suite object.
  CefTestSuite test_suite(argc, argv);

  int retval;

  if (settings.multi_threaded_message_loop) {
    // Run the test suite on the main thread.
    retval = test_suite.Run();
  } else {
    // Create the test thread.
    scoped_ptr<CefTestThread> thread;
    thread.reset(new CefTestThread(&test_suite));
    if (!thread->Start())
      return 1;

    // Start the tests from the UI thread so that any pending UI tasks get a
    // chance to execute first.
    CefPostTask(TID_UI, NewCefRunnableFunction(RunTests, thread.get()));

    // Run the CEF message loop.
    CefRunMessageLoop();

    // The test suite has completed.
    retval = thread->retval();

    // Terminate the test thread.
    thread.reset();
  }

  // Shut down CEF.
  CefShutdown();

#if defined(OS_MACOSX)
  // Platform-specific cleanup.
  extern void PlatformCleanup();
  PlatformCleanup();
#endif

  return retval;
}
