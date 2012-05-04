// Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_DLL_CEF_LOGGING_H_
#define CEF_LIBCEF_DLL_CEF_LOGGING_H_
#pragma once

#ifdef BUILDING_CEF_SHARED
#include "base/logging.h"
#else
#include <assert.h>  // NOLINT(build/include_order)
#define DCHECK(condition) assert(condition)
#define DCHECK_EQ(val1, val2) DCHECK(val1 == val2)
#define DCHECK_NE(val1, val2) DCHECK(val1 != val2)
#define DCHECK_LE(val1, val2) DCHECK(val1 <= val2)
#define DCHECK_LT(val1, val2) DCHECK(val1 < val2)
#define DCHECK_GE(val1, val2) DCHECK(val1 >= val2)
#define DCHECK_GT(val1, val2) DCHECK(val1 > val2)
#endif

#endif  // CEF_LIBCEF_DLL_CEF_LOGGING_H_
