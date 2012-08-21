#ifndef CEF_TESTS_CEFCLIENT_UTIL_H_
#define CEF_TESTS_CEFCLIENT_UTIL_H_
#pragma once

#include "include/cef_task.h"

#include <assert.h>  // NOLINT(build/include_order)

#ifndef NDEBUG
#define ASSERT(condition) if (!(condition)) { assert(false); }
#else
#define ASSERT(condition) ((void)0)
#endif

#define REQUIRE_UI_THREAD()   ASSERT(CefCurrentlyOn(TID_UI));
#define REQUIRE_IO_THREAD()   ASSERT(CefCurrentlyOn(TID_IO));
#define REQUIRE_FILE_THREAD() ASSERT(CefCurrentlyOn(TID_FILE));

#endif  // CEF_TESTS_CEFCLIENT_UTIL_H_
