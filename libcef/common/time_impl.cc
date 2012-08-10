// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/common/time_util.h"

void cef_time_to_basetime(const cef_time_t& cef_time, base::Time& time) {
  base::Time::Exploded exploded;
  exploded.year = cef_time.year;
  exploded.month = cef_time.month;
  exploded.day_of_week = cef_time.day_of_week;
  exploded.day_of_month = cef_time.day_of_month;
  exploded.hour = cef_time.hour;
  exploded.minute = cef_time.minute;
  exploded.second = cef_time.second;
  exploded.millisecond = cef_time.millisecond;
  time = base::Time::FromUTCExploded(exploded);
}

void cef_time_from_basetime(const base::Time& time, cef_time_t& cef_time) {
  base::Time::Exploded exploded;
  time.UTCExplode(&exploded);
  cef_time.year = exploded.year;
  cef_time.month = exploded.month;
  cef_time.day_of_week = exploded.day_of_week;
  cef_time.day_of_month = exploded.day_of_month;
  cef_time.hour = exploded.hour;
  cef_time.minute = exploded.minute;
  cef_time.second = exploded.second;
  cef_time.millisecond = exploded.millisecond;
}

CEF_EXPORT int cef_time_to_timet(const cef_time_t* cef_time, time_t* time) {
  if (!cef_time || !time)
    return 0;

  base::Time base_time;
  cef_time_to_basetime(*cef_time, base_time);
  *time = base_time.ToTimeT();
  return 1;
}

CEF_EXPORT int cef_time_from_timet(time_t time, cef_time_t* cef_time) {
  if (!cef_time)
    return 0;

  base::Time base_time = base::Time::FromTimeT(time);
  cef_time_from_basetime(base_time, *cef_time);
  return 1;
}

CEF_EXPORT int cef_time_to_doublet(const cef_time_t* cef_time, double* time) {
  if (!cef_time || !time)
    return 0;

  base::Time base_time;
  cef_time_to_basetime(*cef_time, base_time);
  *time = base_time.ToDoubleT();
  return 1;
}

CEF_EXPORT int cef_time_from_doublet(double time, cef_time_t* cef_time) {
  if (!cef_time)
    return 0;

  base::Time base_time = base::Time::FromDoubleT(time);
  cef_time_from_basetime(base_time, *cef_time);
  return 1;
}
