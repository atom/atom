// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_THREAD_UTIL_H_
#define CEF_LIBCEF_BROWSER_THREAD_UTIL_H_
#pragma once

#include "base/location.h"
#include "base/logging.h"
#include "content/public/browser/browser_thread.h"

#define CEF_UIT content::BrowserThread::UI
#define CEF_IOT content::BrowserThread::IO
#define CEF_FILET content::BrowserThread::FILE

#define CEF_CURRENTLY_ON(id) content::BrowserThread::CurrentlyOn(id)
#define CEF_CURRENTLY_ON_UIT() CEF_CURRENTLY_ON(CEF_UIT)
#define CEF_CURRENTLY_ON_IOT() CEF_CURRENTLY_ON(CEF_IOT)
#define CEF_CURRENTLY_ON_FILET() CEF_CURRENTLY_ON(CEF_FILET)

#define CEF_REQUIRE(id) DCHECK(CEF_CURRENTLY_ON(id))
#define CEF_REQUIRE_UIT() CEF_REQUIRE(CEF_UIT)
#define CEF_REQUIRE_IOT() CEF_REQUIRE(CEF_IOT)
#define CEF_REQUIRE_FILET() CEF_REQUIRE(CEF_FILET)

#define CEF_REQUIRE_RETURN(id, var) \
  if (!CEF_CURRENTLY_ON(id)) { \
    NOTREACHED() << "called on invalid thread"; \
    return var; \
  }
#define CEF_REQUIRE_UIT_RETURN(var) CEF_REQUIRE_RETURN(CEF_UIT, var)
#define CEF_REQUIRE_IOT_RETURN(var) CEF_REQUIRE_RETURN(CEF_IOT, var)

#define CEF_REQUIRE_RETURN_VOID(id) \
  if (!CEF_CURRENTLY_ON(id)) { \
    NOTREACHED() << "called on invalid thread"; \
    return; \
  }
#define CEF_REQUIRE_UIT_RETURN_VOID() CEF_REQUIRE_RETURN_VOID(CEF_UIT)
#define CEF_REQUIRE_IOT_RETURN_VOID() CEF_REQUIRE_RETURN_VOID(CEF_IOT)

#define CEF_POST_TASK(id, task) \
    content::BrowserThread::PostTask(id, FROM_HERE, task)
#define CEF_POST_DELAYED_TASK(id, task, delay_ms) \
    content::BrowserThread::PostDelayedTask(id, FROM_HERE, task, delay_ms)

#endif  // CEF_LIBCEF_BROWSER_THREAD_UTIL_H_
