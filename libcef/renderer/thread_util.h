// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_RENDERER_THREAD_UTIL_H_
#define CEF_LIBCEF_RENDERER_THREAD_UTIL_H_
#pragma once

#include "libcef/renderer/content_renderer_client.h"

#include "base/location.h"
#include "base/logging.h"
#include "content/public/renderer/render_thread.h"

#define CEF_CURRENTLY_ON_RT() (!!content::RenderThread::Get())

#define CEF_REQUIRE_RT() DCHECK(CEF_CURRENTLY_ON_RT())

#define CEF_REQUIRE_RT_RETURN(var) \
  if (!CEF_CURRENTLY_ON_RT()) { \
    NOTREACHED() << "called on invalid thread"; \
    return var; \
  }

#define CEF_REQUIRE_RT_RETURN_VOID() \
  if (!CEF_CURRENTLY_ON_RT()) { \
    NOTREACHED() << "called on invalid thread"; \
    return; \
  }

#define CEF_RENDER_LOOP() (CefContentRendererClient::Get()->render_loop())

#define CEF_POST_TASK_RT(task) \
    CEF_RENDER_LOOP()->PostTask(FROM_HERE, task)
#define CEF_POST_DELAYED_TASK_RT(task, delay_ms) \
    CEF_RENDER_LOOP()->PostDelayedTask(FROM_HERE, task, delay_ms)

// Use this template in conjuction with RefCountedThreadSafe when you want to
// ensure that an object is deleted on the render thread.
struct CefDeleteOnRenderThread {
  template<typename T>
  static void Destruct(const T* x) {
    if (CEF_CURRENTLY_ON_RT()) {
      delete x;
    } else {
      if (!CEF_RENDER_LOOP()->DeleteSoon(FROM_HERE, x)) {
#if defined(UNIT_TEST)
        // Only logged under unit testing because leaks at shutdown
        // are acceptable under normal circumstances.
        LOG(ERROR) << "DeleteSoon failed on thread " << thread;
#endif  // UNIT_TEST
      }
    }
  }
};

#endif  // CEF_LIBCEF_RENDERER_THREAD_UTIL_H_
