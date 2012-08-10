// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "chrome/browser/diagnostics/sqlite_diagnostics.h"

// Used by SQLitePersistentCookieStore
sql::ErrorDelegate* GetErrorHandlerForCookieDb() {
  return NULL;
}
