// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

// Defines all the "cef" command-line switches.

#ifndef CEF_LIBCEF_COMMON_CEF_SWITCHES_H_
#define CEF_LIBCEF_COMMON_CEF_SWITCHES_H_
#pragma once

namespace switches {

extern const char kProductVersion[];
extern const char kLocale[];
extern const char kLogFile[];
extern const char kLogSeverity[];
extern const char kLogSeverity_Verbose[];
extern const char kLogSeverity_Info[];
extern const char kLogSeverity_Warning[];
extern const char kLogSeverity_Error[];
extern const char kLogSeverity_ErrorReport[];
extern const char kLogSeverity_Disable[];
extern const char kPackFilePath[];
extern const char kLocalesDirPath[];
extern const char kPackLoadingDisabled[];

}  // namespace switches

#endif  // CEF_LIBCEF_COMMON_CEF_SWITCHES_H_
