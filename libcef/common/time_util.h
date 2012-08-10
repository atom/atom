// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_TIME_UTIL_H_
#define CEF_LIBCEF_COMMON_TIME_UTIL_H_
#pragma once

#include "include/internal/cef_time.h"
#include "base/time.h"

// Converts cef_time_t to/from a base::Time object.
void cef_time_to_basetime(const cef_time_t& cef_time, base::Time& time);
void cef_time_from_basetime(const base::Time& time, cef_time_t& cef_time);

#endif  // CEF_LIBCEF_COMMON_TIME_UTIL_H_
