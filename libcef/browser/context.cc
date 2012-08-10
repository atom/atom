// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/context.h"
#include "libcef/browser/browser_context.h"
#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/browser_main.h"
#include "libcef/browser/browser_message_loop.h"
#include "libcef/browser/content_browser_client.h"
#include "libcef/browser/devtools_scheme_handler.h"
#include "libcef/browser/thread_util.h"
#include "libcef/common/main_delegate.h"

#include "base/bind.h"
#include "base/command_line.h"
#include "base/file_util.h"
#include "base/synchronization/waitable_event.h"
#include "content/public/app/content_main.h"
#include "content/public/app/content_main_runner.h"
#include "content/public/common/content_switches.h"
#include "sandbox/src/sandbox_types.h"
#include "ui/base/ui_base_switches.h"

#if defined(OS_MACOSX)
#include "libcef/browser/application_mac.h"
#endif

#if defined(OS_WIN)
#include "content/public/app/startup_helper_win.h"
#endif

// Both the CefContext constuctor and the CefContext::RemoveBrowser method need
// to initialize or reset to the same value.
const int kNextBrowserIdReset = 1;

// Global CefContext pointer
CefRefPtr<CefContext> _Context;


int CefExecuteProcess(const CefMainArgs& args,
                      CefRefPtr<CefApp> application) {
  CommandLine command_line(CommandLine::NO_PROGRAM);
#if defined(OS_WIN)
  command_line.ParseFromString(::GetCommandLineW());
#else
  command_line.InitFromArgv(args.argc, args.argv);
#endif

  // If no process type is specified then it represents the browser process and
  // we do nothing.
  std::string process_type =
      command_line.GetSwitchValueASCII(switches::kProcessType);
  if (process_type.empty())
    return -1;

#if defined(OS_MACOSX)
  // Create the CefCrApplication instance.
  CefCrApplicationCreate();
#endif

  CefMainDelegate main_delegate(application);

  // Execute the secondary process.
#if defined(OS_WIN)
  sandbox::SandboxInterfaceInfo sandbox_info = {0};
  content::InitializeSandboxInfo(&sandbox_info);

  return content::ContentMain(args.instance, &sandbox_info, &main_delegate);
#else
  return content::ContentMain(args.argc, const_cast<const char**>(args.argv),
                              &main_delegate);
#endif
}

bool CefInitialize(const CefMainArgs& args,
                   const CefSettings& settings,
                   CefRefPtr<CefApp> application) {
  // Return true if the global context already exists.
  if (_Context.get())
    return true;

  if (settings.size != sizeof(cef_settings_t)) {
    NOTREACHED() << "invalid CefSettings structure size";
    return false;
  }

  // Create the new global context object.
  _Context = new CefContext();

  // Initialize the global context.
  return _Context->Initialize(args, settings, application);
}

void CefShutdown() {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return;
  }

  // Must always be called on the same thread as Initialize.
  if (!_Context->OnInitThread()) {
    NOTREACHED() << "called on invalid thread";
    return;
  }

  // Shut down the global context. This will block until shutdown is complete.
  _Context->Shutdown();

  // Delete the global context object.
  _Context = NULL;
}

void CefDoMessageLoopWork() {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return;
  }

  // Must always be called on the same thread as Initialize.
  if (!_Context->OnInitThread()) {
    NOTREACHED() << "called on invalid thread";
    return;
  }

  CefBrowserMessageLoop::current()->DoMessageLoopIteration();
}

void CefRunMessageLoop() {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return;
  }

  // Must always be called on the same thread as Initialize.
  if (!_Context->OnInitThread()) {
    NOTREACHED() << "called on invalid thread";
    return;
  }

  CefBrowserMessageLoop::current()->RunMessageLoop();
}

void CefQuitMessageLoop() {
  // Verify that the context is in a valid state.
  if (!CONTEXT_STATE_VALID()) {
    NOTREACHED() << "context not valid";
    return;
  }

  // Must always be called on the same thread as Initialize.
  if (!_Context->OnInitThread()) {
    NOTREACHED() << "called on invalid thread";
    return;
  }

  CefBrowserMessageLoop::current()->Quit();
}


// CefContext

CefContext::CefContext()
  : initialized_(false),
    shutting_down_(false),
    init_thread_id_(0),
    next_browser_id_(kNextBrowserIdReset) {
}

CefContext::~CefContext() {
  if (!shutting_down_)
    Shutdown();
}

bool CefContext::Initialize(const CefMainArgs& args,
                            const CefSettings& settings,
                            CefRefPtr<CefApp> application) {
  init_thread_id_ = base::PlatformThread::CurrentId();
  settings_ = settings;

  cache_path_ = FilePath(CefString(&settings.cache_path));
  if (!cache_path_.empty() &&
      !file_util::DirectoryExists(cache_path_) &&
      !file_util::CreateDirectory(cache_path_)) {
    NOTREACHED() << "The cache_path directory could not be created";
    cache_path_ = FilePath();
  }

#if !defined(OS_WIN)
  if (settings.multi_threaded_message_loop) {
    NOTIMPLEMENTED() << "multi_threaded_message_loop is not supported.";
    return false;
  }
#endif

  main_delegate_.reset(new CefMainDelegate(application));
  main_runner_.reset(content::ContentMainRunner::Create());

  int exit_code;

  // Initialize the content runner.
#if defined(OS_WIN)
  sandbox::SandboxInterfaceInfo sandbox_info = {0};
  content::InitializeSandboxInfo(&sandbox_info);

  exit_code = main_runner_->Initialize(args.instance, &sandbox_info,
                                       main_delegate_.get());
#else
  exit_code = main_runner_->Initialize(args.argc,
                                       const_cast<const char**>(args.argv),
                                       main_delegate_.get());
#endif

  DCHECK_LT(exit_code, 0);
  if (exit_code >= 0)
    return false;

  // Run the process. Results in a call to CefMainDelegate::RunProcess() which
  // will create the browser runner and message loop without blocking.
  exit_code = main_runner_->Run();

  initialized_ = true;

  // Continue initialization on the UI thread.
  CEF_POST_TASK(CEF_UIT, base::Bind(&CefContext::OnContextInitialized, this));

  return true;
}

void CefContext::Shutdown() {
  // Must always be called on the same thread as Initialize.
  DCHECK(OnInitThread());

  shutting_down_ = true;

  if (settings_.multi_threaded_message_loop) {
    // Events that will be used to signal when shutdown is complete. Start in
    // non-signaled mode so that the event will block.
    base::WaitableEvent uithread_shutdown_event(false, false);

    // Finish shutdown on the UI thread.
    CEF_POST_TASK(CEF_UIT,
        base::Bind(&CefContext::FinishShutdownOnUIThread, this,
                   &uithread_shutdown_event));

    /// Block until UI thread shutdown is complete.
    uithread_shutdown_event.Wait();

    FinalizeShutdown();
  } else {
    // Finish shutdown on the current thread, which should be the UI thread.
    FinishShutdownOnUIThread(NULL);

    FinalizeShutdown();
  }
}

bool CefContext::OnInitThread() {
  return (base::PlatformThread::CurrentId() == init_thread_id_);
}

bool CefContext::AddBrowser(CefRefPtr<CefBrowserHostImpl> browser) {
  bool found = false;

  AutoLock lock_scope(this);

  // check that the browser isn't already in the list before adding
  BrowserList::const_iterator it = browserlist_.begin();
  for (; it != browserlist_.end(); ++it) {
    if (it->get() == browser.get()) {
      found = true;
      break;
    }
  }

  if (!found) {
    browser->SetUniqueId(next_browser_id_++);
    browserlist_.push_back(browser);
  }

  return !found;
}

bool CefContext::RemoveBrowser(CefRefPtr<CefBrowserHostImpl> browser) {
  bool deleted = false;

  {
    AutoLock lock_scope(this);

    BrowserList::iterator it = browserlist_.begin();
    for (; it != browserlist_.end(); ++it) {
      if (it->get() == browser.get()) {
        browserlist_.erase(it);
        deleted = true;
        break;
      }
    }

    if (browserlist_.empty())
      next_browser_id_ = kNextBrowserIdReset;
  }

  return deleted;
}

CefRefPtr<CefBrowserHostImpl> CefContext::GetBrowserByID(int id) {
  AutoLock lock_scope(this);

  BrowserList::const_iterator it = browserlist_.begin();
  for (; it != browserlist_.end(); ++it) {
    if (it->get()->unique_id() == id)
      return it->get();
  }

  DLOG(ERROR) << "No browser matching unique id " << id;
  return NULL;
}

CefRefPtr<CefBrowserHostImpl> CefContext::GetBrowserByRoutingID(
    int render_process_id, int render_view_id) {
  AutoLock lock_scope(this);

  BrowserList::const_iterator it = browserlist_.begin();
  for (; it != browserlist_.end(); ++it) {
    if (it->get()->HasIDMatch(render_process_id, render_view_id))
      return it->get();
  }

  DLOG(ERROR) << "No browser matching process id " << render_process_id <<
                 " and view id " << render_view_id;
  return NULL;
}

CefRefPtr<CefApp> CefContext::application() const {
  return main_delegate_->content_client()->application();
}

CefBrowserContext* CefContext::browser_context() const {
  return main_delegate_->browser_client()->browser_main_parts()->
      browser_context();
}

CefDevToolsDelegate* CefContext::devtools_delegate() const {
  return main_delegate_->browser_client()->browser_main_parts()->
      devtools_delegate();
}

void CefContext::OnContextInitialized() {
  CEF_REQUIRE_UIT();

  // Perform DevTools scheme registration.
  RegisterDevToolsSchemeHandler();

  // Notify the handler.
  CefRefPtr<CefApp> app = application();
  if (app.get()) {
    CefRefPtr<CefBrowserProcessHandler> handler =
        app->GetBrowserProcessHandler();
    if (handler.get())
      handler->OnContextInitialized();
  }
}

void CefContext::FinishShutdownOnUIThread(
    base::WaitableEvent* uithread_shutdown_event) {
  CEF_REQUIRE_UIT();

  BrowserList list;

  {
    AutoLock lock_scope(this);
    if (!browserlist_.empty()) {
      list = browserlist_;
      browserlist_.clear();
    }
  }

  // Destroy any remaining browser windows.
  if (!list.empty()) {
    BrowserList::iterator it = list.begin();
    for (; it != list.end(); ++it)
      (*it)->DestroyBrowser();
  }

  if (uithread_shutdown_event)
    uithread_shutdown_event->Signal();
}

void CefContext::FinalizeShutdown() {
  // Shut down the browser runner or UI thread.
  main_delegate_->ShutdownBrowser();

  // Shut down the content runner.
  main_runner_->Shutdown();

  main_runner_.reset(NULL);
  main_delegate_.reset(NULL);
}
