// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "include/cef_task.h"
#include "libcef/browser/thread_util.h"
#include "libcef/renderer/thread_util.h"

#include "base/bind.h"

using content::BrowserThread;

namespace {

const int kRenderThreadId = -1;
const int kInvalidThreadId = -10;

int GetThreadId(CefThreadId threadId) {
  int id = kInvalidThreadId;

  switch (threadId) {
  case TID_UI:
    id = BrowserThread::UI;
    break;
  case TID_DB:
    id = BrowserThread::DB;
    break;
  case TID_FILE:
    id = BrowserThread::FILE;
    break;
  case TID_FILE_USER_BLOCKING:
    id = BrowserThread::FILE_USER_BLOCKING;
    break;
  case TID_PROCESS_LAUNCHER:
    id = BrowserThread::PROCESS_LAUNCHER;
    break;
  case TID_CACHE:
    id = BrowserThread::CACHE;
    break;
  case TID_IO:
    id = BrowserThread::IO;
    break;
  case TID_RENDERER:
    id = kRenderThreadId;
    break;
  default:
    NOTREACHED() << "invalid thread id " << threadId;
    return kInvalidThreadId;
  };

  if (id >= 0) {
    // Verify that we're on the browser process.
    if (content::GetContentClient()->browser())
      return id;
    NOTREACHED() << "called on invalid process";
  } else if (id == kRenderThreadId) {
    // Verify that we're on the renderer process.
    if (content::GetContentClient()->renderer())
      return id;
    NOTREACHED() << "called on invalid process";
  }

  return kInvalidThreadId;
}

}  // namespace

bool CefCurrentlyOn(CefThreadId threadId) {
  int id = GetThreadId(threadId);
  if (id >= 0) {
    // Browser process.
    return CEF_CURRENTLY_ON(static_cast<BrowserThread::ID>(id));
  } else if (id == kRenderThreadId) {
    // Renderer process.
    return CEF_CURRENTLY_ON_RT();
  }
  return false;
}

bool CefPostTask(CefThreadId threadId, CefRefPtr<CefTask> task) {
  int id = GetThreadId(threadId);
  if (id >= 0) {
    // Browser process.
    return CEF_POST_TASK(static_cast<BrowserThread::ID>(id),
        base::Bind(&CefTask::Execute, task, threadId));
  } else if (id == kRenderThreadId) {
    // Renderer process.
    return CEF_POST_TASK_RT(base::Bind(&CefTask::Execute, task, threadId));
  }
  return false;
}

bool CefPostDelayedTask(CefThreadId threadId, CefRefPtr<CefTask> task,
                        int64 delay_ms) {
  int id = GetThreadId(threadId);
  if (id >= 0) {
    // Browser process.
    return CEF_POST_DELAYED_TASK(static_cast<BrowserThread::ID>(id),
        base::Bind(&CefTask::Execute, task, threadId), delay_ms);
  } else if (id == kRenderThreadId) {
    // Renderer process.
    return CEF_POST_DELAYED_TASK_RT(
        base::Bind(&CefTask::Execute, task, threadId), delay_ms);
  }
  return false;
}
