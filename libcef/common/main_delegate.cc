// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/common/main_delegate.h"
#include "libcef/browser/content_browser_client.h"
#include "libcef/browser/context.h"
#include "libcef/common/cef_switches.h"
#include "libcef/common/command_line_impl.h"
#include "libcef/renderer/content_renderer_client.h"

#include "base/command_line.h"
#include "base/file_path.h"
#include "base/file_util.h"
#include "base/path_service.h"
#include "base/string_number_conversions.h"
#include "base/string_util.h"
#include "base/synchronization/waitable_event.h"
#include "base/threading/thread.h"
#include "content/public/browser/browser_main_runner.h"
#include "content/public/browser/render_process_host.h"
#include "content/public/common/content_switches.h"
#include "content/public/common/main_function_params.h"
#include "ui/base/resource/resource_bundle.h"
#include "ui/base/ui_base_paths.h"

#if defined(OS_WIN)
#include <Objbase.h>  // NOLINT(build/include_order)
#endif

#if defined(OS_MACOSX)
#include "base/mac/bundle_locations.h"
#include "base/mac/foundation_util.h"
#include "content/public/common/content_paths.h"
#endif

namespace {

#if defined(OS_MACOSX)

FilePath GetFrameworksPath() {
  // Start out with the path to the running executable.
  FilePath execPath;
  PathService::Get(base::FILE_EXE, &execPath);

  // Get the main bundle path.
  FilePath bundlePath = base::mac::GetAppBundlePath(execPath);

  // Go into the Contents/Frameworks directory.
  return bundlePath.Append(FILE_PATH_LITERAL("Contents"))
                   .Append(FILE_PATH_LITERAL("Frameworks"));
}

// The framework bundle path is used for loading resources, libraries, etc.
FilePath GetFrameworkBundlePath() {
  return GetFrameworksPath().Append(
      FILE_PATH_LITERAL("Chromium Embedded Framework.framework"));
}

FilePath GetDefaultPackPath() {
  return GetFrameworkBundlePath().Append(FILE_PATH_LITERAL("Resources"));
}

void OverrideFrameworkBundlePath() {
  base::mac::SetOverrideFrameworkBundlePath(GetFrameworkBundlePath());
}

void OverrideChildProcessPath() {
  // Retrieve the name of the running executable.
  FilePath path;
  PathService::Get(base::FILE_EXE, &path);

  std::string name = path.BaseName().value();

  FilePath helper_path = GetFrameworksPath()
      .Append(FILE_PATH_LITERAL(name+" Helper.app"))
      .Append(FILE_PATH_LITERAL("Contents"))
      .Append(FILE_PATH_LITERAL("MacOS"))
      .Append(FILE_PATH_LITERAL(name+" Helper"));

  PathService::Override(content::CHILD_PROCESS_EXE, helper_path);
}

#else  // !defined(OS_MACOSX)

FilePath GetDefaultPackPath() {
  FilePath pak_dir;
  PathService::Get(base::DIR_MODULE, &pak_dir);
  return pak_dir;
}

#endif  // !defined(OS_MACOSX)

// Used to run the UI on a separate thread.
class CefUIThread : public base::Thread {
 public:
  explicit CefUIThread(const content::MainFunctionParams& main_function_params)
    : base::Thread("CefUIThread"),
      main_function_params_(main_function_params) {
  }

  virtual void Init() OVERRIDE {
#if defined(OS_WIN)
    // Initializes the COM library on the current thread.
    CoInitialize(NULL);
#endif

    // Use our own browser process runner.
    browser_runner_.reset(content::BrowserMainRunner::Create());

    // Initialize browser process state. Uses the current thread's mesage loop.
    int exit_code = browser_runner_->Initialize(main_function_params_);
    CHECK_EQ(exit_code, -1);
  }

  virtual void CleanUp() OVERRIDE {
    browser_runner_->Shutdown();
    browser_runner_.reset(NULL);

#if defined(OS_WIN)
    // Closes the COM library on the current thread. CoInitialize must
    // be balanced by a corresponding call to CoUninitialize.
    CoUninitialize();
#endif
  }

 protected:
  content::MainFunctionParams main_function_params_;
  scoped_ptr<content::BrowserMainRunner> browser_runner_;
};

}  // namespace

CefMainDelegate::CefMainDelegate(CefRefPtr<CefApp> application)
    : content_client_(application) {
}

CefMainDelegate::~CefMainDelegate() {
}

bool CefMainDelegate::BasicStartupComplete(int* exit_code) {
#if defined(OS_MACOSX)
  OverrideFrameworkBundlePath();
#endif

  CommandLine* command_line = CommandLine::ForCurrentProcess();
  std::string process_type =
      command_line->GetSwitchValueASCII(switches::kProcessType);

  if (process_type.empty()) {
    // In the browser process. Populate the global command-line object.
    const CefSettings& settings = _Context->settings();

    if (settings.command_line_args_disabled) {
      // Remove any existing command-line arguments.
      CommandLine::StringVector argv;
      argv.push_back(command_line->GetProgram().value());
      command_line->InitFromArgv(argv);

      const CommandLine::SwitchMap& map = command_line->GetSwitches();
      const_cast<CommandLine::SwitchMap*>(&map)->clear();
    }

    if (settings.single_process)
      command_line->AppendSwitch(switches::kSingleProcess);

    if (settings.browser_subprocess_path.length > 0) {
      FilePath file_path =
          FilePath(CefString(&settings.browser_subprocess_path));
      if (!file_path.empty()) {
        command_line->AppendSwitchPath(switches::kBrowserSubprocessPath,
                                       file_path);
      }
    }

    if (settings.user_agent.length > 0) {
      command_line->AppendSwitchASCII(switches::kUserAgent,
          CefString(&settings.user_agent));
    } else if (settings.product_version.length > 0) {
      command_line->AppendSwitchASCII(switches::kProductVersion,
          CefString(&settings.product_version));
    }

    if (settings.locale.length > 0) {
      command_line->AppendSwitchASCII(switches::kLocale,
          CefString(&settings.locale));
    }

    if (settings.log_file.length > 0) {
      FilePath file_path = FilePath(CefString(&settings.log_file));
      if (!file_path.empty())
        command_line->AppendSwitchPath(switches::kLogFile, file_path);
    }

    if (settings.log_severity != LOGSEVERITY_DEFAULT) {
      std::string log_severity;
      switch (settings.log_severity) {
        case LOGSEVERITY_VERBOSE:
          log_severity = switches::kLogSeverity_Verbose;
          break;
        case LOGSEVERITY_INFO:
          log_severity = switches::kLogSeverity_Info;
          break;
        case LOGSEVERITY_WARNING:
          log_severity = switches::kLogSeverity_Warning;
          break;
        case LOGSEVERITY_ERROR:
          log_severity = switches::kLogSeverity_Error;
          break;
        case LOGSEVERITY_ERROR_REPORT:
          log_severity = switches::kLogSeverity_ErrorReport;
          break;
        case LOGSEVERITY_DISABLE:
          log_severity = switches::kLogSeverity_Disable;
          break;
        default:
          break;
      }
      if (!log_severity.empty())
        command_line->AppendSwitchASCII(switches::kLogSeverity, log_severity);
    }

    if (settings.javascript_flags.length > 0) {
      command_line->AppendSwitchASCII(switches::kJavaScriptFlags,
          CefString(&settings.javascript_flags));
    }

    if (settings.pack_loading_disabled) {
      command_line->AppendSwitch(switches::kPackLoadingDisabled);
    } else {
      if (settings.pack_file_path.length > 0) {
        FilePath file_path = FilePath(CefString(&settings.pack_file_path));
        if (!file_path.empty())
          command_line->AppendSwitchPath(switches::kPackFilePath, file_path);
      }

      if (settings.locales_dir_path.length > 0) {
        FilePath file_path = FilePath(CefString(&settings.locales_dir_path));
        if (!file_path.empty())
          command_line->AppendSwitchPath(switches::kLocalesDirPath, file_path);
      }
    }

    if (settings.remote_debugging_port >= 1024 &&
        settings.remote_debugging_port <= 65535) {
      command_line->AppendSwitchASCII(switches::kRemoteDebuggingPort,
          base::IntToString(settings.remote_debugging_port));
    }

    // TODO(cef): Figure out how to support the sandbox.
    if (!command_line->HasSwitch(switches::kNoSandbox))
      command_line->AppendSwitch(switches::kNoSandbox);
  }

  if (content_client_.application().get()) {
    // Give the application a chance to view/modify the command line.
    CefRefPtr<CefCommandLineImpl> commandLinePtr(
        new CefCommandLineImpl(command_line, false, false));
    content_client_.application()->OnBeforeCommandLineProcessing(
        CefString(process_type), commandLinePtr.get());
    commandLinePtr->Detach(NULL);
  }

  // Initialize logging.
  FilePath log_file = command_line->GetSwitchValuePath(switches::kLogFile);
  std::string log_severity_str =
      command_line->GetSwitchValueASCII(switches::kLogSeverity);

  logging::LogSeverity log_severity = logging::LOG_INFO;
  if (!log_severity_str.empty()) {
    if (LowerCaseEqualsASCII(log_severity_str,
                             switches::kLogSeverity_Verbose)) {
      log_severity = logging::LOG_VERBOSE;
    } else if (LowerCaseEqualsASCII(log_severity_str,
                                    switches::kLogSeverity_Warning)) {
      log_severity = logging::LOG_WARNING;
    } else if (LowerCaseEqualsASCII(log_severity_str,
                                    switches::kLogSeverity_Error)) {
      log_severity = logging::LOG_ERROR;
    } else if (LowerCaseEqualsASCII(log_severity_str,
                                    switches::kLogSeverity_ErrorReport)) {
      log_severity = logging::LOG_ERROR_REPORT;
    } else if (LowerCaseEqualsASCII(log_severity_str,
                                    switches::kLogSeverity_Disable)) {
      log_severity = LOGSEVERITY_DISABLE;
    }
  }

  logging::LoggingDestination logging_dest;
  if (log_severity == LOGSEVERITY_DISABLE) {
    logging_dest = logging::LOG_NONE;
  } else {
#if defined(OS_WIN)
    logging_dest = logging::LOG_ONLY_TO_FILE;
#else
    logging_dest = logging::LOG_TO_BOTH_FILE_AND_SYSTEM_DEBUG_LOG;
#endif
    logging::SetMinLogLevel(log_severity);
  }

  logging::InitLogging(log_file.value().c_str(), logging_dest,
      logging::DONT_LOCK_LOG_FILE, logging::APPEND_TO_OLD_LOG_FILE,
      logging::DISABLE_DCHECK_FOR_NON_OFFICIAL_RELEASE_BUILDS);

  content::SetContentClient(&content_client_);

  return false;
}

void CefMainDelegate::PreSandboxStartup() {
#if defined(OS_MACOSX)
  OverrideChildProcessPath();
#endif

  const CommandLine& command_line = *CommandLine::ForCurrentProcess();
  if (command_line.HasSwitch(switches::kPackLoadingDisabled))
    content_client_.set_pack_loading_disabled(true);

  InitializeResourceBundle();
}

int CefMainDelegate::RunProcess(
    const std::string& process_type,
    const content::MainFunctionParams& main_function_params) {
  if (process_type.empty()) {
    const CefSettings& settings = _Context->settings();
    if (!settings.multi_threaded_message_loop) {
      // Use our own browser process runner.
      browser_runner_.reset(content::BrowserMainRunner::Create());

      // Initialize browser process state. Results in a call to
      // CefBrowserMain::PreMainMessageLoopStart() which creates the UI message
      // loop.
      int exit_code = browser_runner_->Initialize(main_function_params);
      if (exit_code >= 0)
        return exit_code;
    } else {
      // Run the UI on a separate thread.
      scoped_ptr<base::Thread> thread;
      thread.reset(new CefUIThread(main_function_params));
      base::Thread::Options options;
      options.message_loop_type = MessageLoop::TYPE_UI;
      if (!thread->StartWithOptions(options)) {
        NOTREACHED() << "failed to start UI thread";
        return 1;
      }
      ui_thread_.swap(thread);
    }

    return 0;
  }

  return -1;
}

void CefMainDelegate::ProcessExiting(const std::string& process_type) {
  ResourceBundle::CleanupSharedInstance();
}


content::ContentBrowserClient* CefMainDelegate::CreateContentBrowserClient() {
  browser_client_.reset(new CefContentBrowserClient);
  return browser_client_.get();
}

content::ContentRendererClient*
    CefMainDelegate::CreateContentRendererClient() {
  renderer_client_.reset(new CefContentRendererClient);
  return renderer_client_.get();
}

void CefMainDelegate::ShutdownBrowser() {
  if (browser_runner_.get()) {
    browser_runner_->Shutdown();
    browser_runner_.reset(NULL);
  }
  if (ui_thread_.get()) {
    // Blocks until the thread has stopped.
    ui_thread_->Stop();
    ui_thread_.reset();
  }
}

void CefMainDelegate::InitializeResourceBundle() {
  const CommandLine& command_line = *CommandLine::ForCurrentProcess();
  FilePath pak_file, locales_dir;

  if (!content_client_.pack_loading_disabled()) {
    if (command_line.HasSwitch(switches::kPackFilePath))
      pak_file = command_line.GetSwitchValuePath(switches::kPackFilePath);

    if (pak_file.empty())
      pak_file = GetDefaultPackPath().Append(FILE_PATH_LITERAL("cef.pak"));

    if (command_line.HasSwitch(switches::kLocalesDirPath))
      locales_dir = command_line.GetSwitchValuePath(switches::kLocalesDirPath);

    if (!locales_dir.empty())
      PathService::Override(ui::DIR_LOCALES, locales_dir);
  }

  std::string locale = command_line.GetSwitchValueASCII(switches::kLocale);
  if (locale.empty())
    locale = "en-US";

  const std::string loaded_locale =
      ui::ResourceBundle::InitSharedInstanceWithLocale(locale,
                                                       &content_client_);
  if (!content_client_.pack_loading_disabled()) {
    CHECK(!loaded_locale.empty()) << "Locale could not be found for " << locale;

    if (file_util::PathExists(pak_file)) {
      content_client_.set_allow_pack_file_load(true);
      ResourceBundle::GetSharedInstance().AddDataPack(
          pak_file, ui::SCALE_FACTOR_NONE);
      content_client_.set_allow_pack_file_load(false);
    } else {
      NOTREACHED() << "Could not load cef.pak";
    }
  }
}
