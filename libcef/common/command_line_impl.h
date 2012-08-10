// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_COMMAND_LINE_IMPL_H_
#define CEF_LIBCEF_COMMON_COMMAND_LINE_IMPL_H_
#pragma once

#include "include/cef_command_line.h"
#include "libcef/common/value_base.h"

#include "base/command_line.h"

// CefCommandLine implementation
class CefCommandLineImpl : public CefValueBase<CefCommandLine, CommandLine> {
 public:
  CefCommandLineImpl(CommandLine* value,
                     bool will_delete,
                     bool read_only);

  // CefCommandLine methods.
  virtual bool IsValid() OVERRIDE;
  virtual bool IsReadOnly() OVERRIDE;
  virtual CefRefPtr<CefCommandLine> Copy() OVERRIDE;
  virtual void InitFromArgv(int argc, const char* const* argv) OVERRIDE;
  virtual void InitFromString(const CefString& command_line) OVERRIDE;
  virtual void Reset() OVERRIDE;
  virtual CefString GetCommandLineString() OVERRIDE;
  virtual CefString GetProgram() OVERRIDE;
  virtual void SetProgram(const CefString& program) OVERRIDE;
  virtual bool HasSwitches() OVERRIDE;
  virtual bool HasSwitch(const CefString& name) OVERRIDE;
  virtual CefString GetSwitchValue(const CefString& name) OVERRIDE;
  virtual void GetSwitches(SwitchMap& switches) OVERRIDE;
  virtual void AppendSwitch(const CefString& name) OVERRIDE;
  virtual void AppendSwitchWithValue(const CefString& name,
                                     const CefString& value) OVERRIDE;
  virtual bool HasArguments() OVERRIDE;
  virtual void GetArguments(ArgumentList& arguments) OVERRIDE;
  virtual void AppendArgument(const CefString& argument) OVERRIDE;

  // Must hold the controller lock while using this value.
  const CommandLine& command_line() { return const_value(); }

  DISALLOW_COPY_AND_ASSIGN(CefCommandLineImpl);
};

#endif  // CEF_LIBCEF_COMMON_COMMAND_LINE_IMPL_H_
