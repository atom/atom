// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/common/cef_switches.h"

namespace switches {

// Product version string.
const char kProductVersion[]          = "product-version";

// Locale string.
const char kLocale[]                  = "locale";

// Log file path.
const char kLogFile[]                 = "log-file";

// Severity of messages to log.
const char kLogSeverity[]             = "log-severity";
const char kLogSeverity_Verbose[]     = "verbose";
const char kLogSeverity_Info[]        = "info";
const char kLogSeverity_Warning[]     = "warning";
const char kLogSeverity_Error[]       = "error";
const char kLogSeverity_ErrorReport[] = "error-report";
const char kLogSeverity_Disable[]     = "disable";

// Path to cef.pak file.
const char kPackFilePath[]            = "pack-file-path";

// Path to locales directory.
const char kLocalesDirPath[]          = "locales-dir-path";

// Path to locales directory.
const char kPackLoadingDisabled[]     = "pack-loading-disabled";

}  // namespace switches
