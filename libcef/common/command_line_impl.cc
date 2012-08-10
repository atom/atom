// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/common/command_line_impl.h"

#include "base/file_path.h"
#include "base/logging.h"

CefCommandLineImpl::CefCommandLineImpl(CommandLine* value,
                                       bool will_delete,
                                       bool read_only)
  : CefValueBase<CefCommandLine, CommandLine>(
        value, NULL, will_delete ? kOwnerWillDelete : kOwnerNoDelete,
        read_only, NULL) {
}

bool CefCommandLineImpl::IsValid() {
  return !detached();
}

bool CefCommandLineImpl::IsReadOnly() {
  return read_only();
}

CefRefPtr<CefCommandLine> CefCommandLineImpl::Copy() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);
  return new CefCommandLineImpl(
      new CommandLine(const_value().argv()), true, false);
}

void CefCommandLineImpl::InitFromArgv(int argc, const char* const* argv) {
#if !defined(OS_WIN)
  CEF_VALUE_VERIFY_RETURN_VOID(true);
  mutable_value()->InitFromArgv(argc, argv);
#else
  NOTREACHED() << "method not supported on this platform";
#endif
}

void CefCommandLineImpl::InitFromString(const CefString& command_line) {
#if defined(OS_WIN)
  CEF_VALUE_VERIFY_RETURN_VOID(true);
  mutable_value()->ParseFromString(command_line);
#else
  NOTREACHED() << "method not supported on this platform";
#endif
}

void CefCommandLineImpl::Reset() {
  CEF_VALUE_VERIFY_RETURN_VOID(true);
  CommandLine::StringVector argv;
  argv.push_back(mutable_value()->GetProgram().value());
  mutable_value()->InitFromArgv(argv);

  const CommandLine::SwitchMap& map = mutable_value()->GetSwitches();
  const_cast<CommandLine::SwitchMap*>(&map)->clear();
}

CefString CefCommandLineImpl::GetCommandLineString() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetCommandLineString();
}

CefString CefCommandLineImpl::GetProgram() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetProgram().value();
}

void CefCommandLineImpl::SetProgram(const CefString& program) {
  CEF_VALUE_VERIFY_RETURN_VOID(true);
  mutable_value()->SetProgram(FilePath(program));
}

bool CefCommandLineImpl::HasSwitches() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return (const_value().GetSwitches().size() > 0);
}

bool CefCommandLineImpl::HasSwitch(const CefString& name) {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return const_value().HasSwitch(name);
}

CefString CefCommandLineImpl::GetSwitchValue(const CefString& name) {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().GetSwitchValueNative(name);
}

void CefCommandLineImpl::GetSwitches(SwitchMap& switches) {
  CEF_VALUE_VERIFY_RETURN_VOID(false);
  const CommandLine::SwitchMap& map = const_value().GetSwitches();
  CommandLine::SwitchMap::const_iterator it = map.begin();
  for (; it != map.end(); ++it)
    switches.insert(std::make_pair(it->first, it->second));
}

void CefCommandLineImpl::AppendSwitch(const CefString& name) {
  CEF_VALUE_VERIFY_RETURN_VOID(true);
  mutable_value()->AppendSwitch(name);
}

void CefCommandLineImpl::AppendSwitchWithValue(const CefString& name,
                                               const CefString& value) {
  CEF_VALUE_VERIFY_RETURN_VOID(true);
  mutable_value()->AppendSwitchNative(name, value);
}

bool CefCommandLineImpl::HasArguments() {
  CEF_VALUE_VERIFY_RETURN(false, false);
  return (const_value().GetArgs().size() > 0);
}

void CefCommandLineImpl::GetArguments(ArgumentList& arguments) {
  CEF_VALUE_VERIFY_RETURN_VOID(false);
  const CommandLine::StringVector& vec = const_value().GetArgs();
  CommandLine::StringVector::const_iterator it = vec.begin();
  for (; it != vec.end(); ++it)
    arguments.push_back(*it);
}

void CefCommandLineImpl::AppendArgument(const CefString& argument) {
  CEF_VALUE_VERIFY_RETURN_VOID(true);
  mutable_value()->AppendArgNative(argument);
}


// CefCommandLine implementation.

// static
CefRefPtr<CefCommandLine> CefCommandLine::CreateCommandLine() {
  return new CefCommandLineImpl(
      new CommandLine(CommandLine::NO_PROGRAM), true, false);
}

// static
CefRefPtr<CefCommandLine> CefCommandLine::GetGlobalCommandLine() {
  // Uses a singleton reference object.
  static CefRefPtr<CefCommandLineImpl> commandLinePtr;
  if (!commandLinePtr.get()) {
    CommandLine* command_line = CommandLine::ForCurrentProcess();
    if (command_line)
      commandLinePtr = new CefCommandLineImpl(command_line, false, true);
  }
  return commandLinePtr.get();
}
