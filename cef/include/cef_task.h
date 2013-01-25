// Copyright (c) 2013 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ---------------------------------------------------------------------------
//
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//

#ifndef CEF_INCLUDE_CEF_TASK_H_
#define CEF_INCLUDE_CEF_TASK_H_

#include "include/cef_base.h"

typedef cef_thread_id_t CefThreadId;

///
// Implement this interface for asynchronous task execution. If the task is
// posted successfully and if the associated message loop is still running then
// the Execute() method will be called on the target thread. If the task fails
// to post then the task object may be destroyed on the source thread instead of
// the target thread. For this reason be cautious when performing work in the
// task object destructor.
///
/*--cef(source=client)--*/
class CefTask : public virtual CefBase {
 public:
  ///
  // Method that will be executed on the target thread.
  ///
  /*--cef()--*/
  virtual void Execute() =0;
};

///
// Class that asynchronously executes tasks on the associated thread. It is safe
// to call the methods of this class on any thread.
//
// CEF maintains multiple internal threads that are used for handling different
// types of tasks in different processes. The cef_thread_id_t definitions in
// cef_types.h list the common CEF threads. Task runners are also available for
// other CEF threads as appropriate (for example, V8 WebWorker threads).
///
/*--cef(source=library)--*/
class CefTaskRunner : public virtual CefBase {
 public:
  ///
  // Returns the task runner for the current thread. Only CEF threads will have
  // task runners. An empty reference will be returned if this method is called
  // on an invalid thread.
  ///
  /*--cef()--*/
  static CefRefPtr<CefTaskRunner> GetForCurrentThread();

  ///
  // Returns the task runner for the specified CEF thread.
  ///
  /*--cef()--*/
  static CefRefPtr<CefTaskRunner> GetForThread(CefThreadId threadId);

  ///
  // Returns true if this object is pointing to the same task runner as |that|
  // object.
  ///
  /*--cef()--*/
  virtual bool IsSame(CefRefPtr<CefTaskRunner> that) =0;

  ///
  // Returns true if this task runner belongs to the current thread.
  ///
  /*--cef()--*/
  virtual bool BelongsToCurrentThread() =0;

  ///
  // Returns true if this task runner is for the specified CEF thread.
  ///
  /*--cef()--*/
  virtual bool BelongsToThread(CefThreadId threadId) =0;

  ///
  // Post a task for execution on the thread associated with this task runner.
  // Execution will occur asynchronously.
  ///
  /*--cef()--*/
  virtual bool PostTask(CefRefPtr<CefTask> task) =0;

  ///
  // Post a task for delayed execution on the thread associated with this task
  // runner. Execution will occur asynchronously. Delayed tasks are not
  // supported on V8 WebWorker threads and will be executed without the
  // specified delay.
  ///
  /*--cef()--*/
  virtual bool PostDelayedTask(CefRefPtr<CefTask> task, int64 delay_ms) =0;
};


///
// Returns true if called on the specified thread. Equivalent to using
// CefTaskRunner::GetForThread(threadId)->BelongsToCurrentThread().
///
/*--cef()--*/
bool CefCurrentlyOn(CefThreadId threadId);

///
// Post a task for execution on the specified thread. Equivalent to
// using CefTaskRunner::GetForThread(threadId)->PostTask(task).
///
/*--cef()--*/
bool CefPostTask(CefThreadId threadId, CefRefPtr<CefTask> task);

///
// Post a task for delayed execution on the specified thread. Equivalent to
// using CefTaskRunner::GetForThread(threadId)->PostDelayedTask(task, delay_ms).
///
/*--cef()--*/
bool CefPostDelayedTask(CefThreadId threadId, CefRefPtr<CefTask> task,
                        int64 delay_ms);


#endif  // CEF_INCLUDE_CEF_TASK_H_
