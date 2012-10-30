// Copyright (c) 2012 Marshall A. Greenblatt. Portions copyright (c) 2012
// Google Inc. All rights reserved.
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

///
// Trace events are for tracking application performance and resource usage.
// Macros are provided to track:
//    Begin and end of function calls
//    Counters
//
// Events are issued against categories. Whereas LOG's categories are statically
// defined, TRACE categories are created implicitly with a string. For example:
//   CEF_TRACE_EVENT_INSTANT0("MY_SUBSYSTEM", "SomeImportantEvent")
//
// Events can be INSTANT, or can be pairs of BEGIN and END in the same scope:
//   CEF_TRACE_EVENT_BEGIN0("MY_SUBSYSTEM", "SomethingCostly")
//   doSomethingCostly()
//   CEF_TRACE_EVENT_END0("MY_SUBSYSTEM", "SomethingCostly")
// Note: Our tools can't always determine the correct BEGIN/END pairs unless
// these are used in the same scope. Use ASYNC_BEGIN/ASYNC_END macros if you
// need them to be in separate scopes.
//
// A common use case is to trace entire function scopes. This issues a trace
// BEGIN and END automatically:
//   void doSomethingCostly() {
//     CEF_TRACE_EVENT0("MY_SUBSYSTEM", "doSomethingCostly");
//     ...
//   }
//
// Additional parameters can be associated with an event:
//   void doSomethingCostly2(int howMuch) {
//     CEF_TRACE_EVENT1("MY_SUBSYSTEM", "doSomethingCostly",
//         "howMuch", howMuch);
//     ...
//   }
//
// The trace system will automatically add to this information the current
// process id, thread id, and a timestamp in microseconds.
//
// To trace an asynchronous procedure such as an IPC send/receive, use
// ASYNC_BEGIN and ASYNC_END:
//   [single threaded sender code]
//     static int send_count = 0;
//     ++send_count;
//     CEF_TRACE_EVENT_ASYNC_BEGIN0("ipc", "message", send_count);
//     Send(new MyMessage(send_count));
//   [receive code]
//     void OnMyMessage(send_count) {
//       CEF_TRACE_EVENT_ASYNC_END0("ipc", "message", send_count);
//     }
// The third parameter is a unique ID to match ASYNC_BEGIN/ASYNC_END pairs.
// ASYNC_BEGIN and ASYNC_END can occur on any thread of any traced process.
// Pointers can be used for the ID parameter, and they will be mangled
// internally so that the same pointer on two different processes will not
// match. For example:
//   class MyTracedClass {
//    public:
//     MyTracedClass() {
//       CEF_TRACE_EVENT_ASYNC_BEGIN0("category", "MyTracedClass", this);
//     }
//     ~MyTracedClass() {
//       CEF_TRACE_EVENT_ASYNC_END0("category", "MyTracedClass", this);
//     }
//   }
//
// The trace event also supports counters, which is a way to track a quantity
// as it varies over time. Counters are created with the following macro:
//   CEF_TRACE_COUNTER1("MY_SUBSYSTEM", "myCounter", g_myCounterValue);
//
// Counters are process-specific. The macro itself can be issued from any
// thread, however.
//
// Sometimes, you want to track two counters at once. You can do this with two
// counter macros:
//   CEF_TRACE_COUNTER1("MY_SUBSYSTEM", "myCounter0", g_myCounterValue[0]);
//   CEF_TRACE_COUNTER1("MY_SUBSYSTEM", "myCounter1", g_myCounterValue[1]);
// Or you can do it with a combined macro:
//   CEF_TRACE_COUNTER2("MY_SUBSYSTEM", "myCounter",
//       "bytesPinned", g_myCounterValue[0],
//       "bytesAllocated", g_myCounterValue[1]);
// This indicates to the tracing UI that these counters should be displayed
// in a single graph, as a summed area chart.
//
// Since counters are in a global namespace, you may want to disembiguate with a
// unique ID, by using the CEF_TRACE_COUNTER_ID* variations.
//
// By default, trace collection is compiled in, but turned off at runtime.
// Collecting trace data is the responsibility of the embedding application. In
// CEF's case, calling BeginTracing will turn on tracing on all active
// processes.
//
//
// Memory scoping note:
// Tracing copies the pointers, not the string content, of the strings passed
// in for category, name, and arg_names.  Thus, the following code will cause
// problems:
//     char* str = strdup("impprtantName");
//     CEF_TRACE_EVENT_INSTANT0("SUBSYSTEM", str);  // BAD!
//     free(str);                   // Trace system now has dangling pointer
//
// To avoid this issue with the |name| and |arg_name| parameters, use the
// CEF_TRACE_EVENT_COPY_XXX overloads of the macros at additional runtime
// overhead.
// Notes: The category must always be in a long-lived char* (i.e. static const).
//        The |arg_values|, when used, are always deep copied with the _COPY
//        macros.
//
//
// Thread Safety:
// All macros are thread safe and can be used from any process.
///

#ifndef CEF_INCLUDE_CEF_TRACE_EVENT_H_
#define CEF_INCLUDE_CEF_TRACE_EVENT_H_
#pragma once

#include "include/internal/cef_export.h"
#include "include/internal/cef_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Functions for tracing counters and functions; called from macros.
// - |category| string must have application lifetime (static or literal). They
//   may not include "(quotes) chars.
// - |argX_name|, |argX_val|, |valueX_name|, |valeX_val| are optional parameters
//   and represent pairs of name and values of arguments
// - |copy| is used to avoid memory scoping issues with the |name| and
//   |arg_name| parameters by copying them
// - |id| is used to disambiguate counters with the same name, or match async
//   trace events

CEF_EXPORT void cef_trace_event(const char* category,
                                const char* name,
                                const char* arg1_name,
                                uint64 arg1_val,
                                const char* arg2_name,
                                uint64 arg2_val);
CEF_EXPORT void cef_trace_event_instant(const char* category,
                                        const char* name,
                                        const char* arg1_name,
                                        uint64 arg1_val,
                                        const char* arg2_name,
                                        uint64 arg2_val,
                                        int copy);
CEF_EXPORT void cef_trace_event_begin(const char* category,
                                      const char* name,
                                      const char* arg1_name,
                                      uint64 arg1_val,
                                      const char* arg2_name,
                                      uint64 arg2_val,
                                      int copy);
CEF_EXPORT void cef_trace_event_end(const char* category,
                                    const char* name,
                                    const char* arg1_name,
                                    uint64 arg1_val,
                                    const char* arg2_name,
                                    uint64 arg2_val,
                                    int copy);
CEF_EXPORT void cef_trace_event_if_longer_than(long long threshold_us,
                                               const char* category,
                                               const char* name,
                                               const char* arg1_name,
                                               uint64 arg1_val,
                                               const char* arg2_name,
                                               uint64 arg2_val);
CEF_EXPORT void cef_trace_counter(const char* category,
                                  const char* name,
                                  const char* value1_name,
                                  uint64 value1_val,
                                  const char* value2_name,
                                  uint64 value2_val,
                                  int copy);
CEF_EXPORT void cef_trace_counter_id(const char* category,
                                     const char* name,
                                     uint64 id,
                                     const char* value1_name,
                                     uint64 value1_val,
                                     const char* value2_name,
                                     uint64 value2_val,
                                     int copy);
CEF_EXPORT void cef_trace_event_async_begin(const char* category,
                                            const char* name,
                                            uint64 id,
                                            const char* arg1_name,
                                            uint64 arg1_val,
                                            const char* arg2_name,
                                            uint64 arg2_val,
                                            int copy);
CEF_EXPORT void cef_trace_event_async_step(const char* category,
                                           const char* name,
                                           uint64 id,
                                           uint64 step,
                                           const char* arg1_name,
                                           uint64 arg1_val,
                                           int copy);
CEF_EXPORT void cef_trace_event_async_end(const char* category,
                                          const char* name,
                                          uint64 id,
                                          const char* arg1_name,
                                          uint64 arg1_val,
                                          const char* arg2_name,
                                          uint64 arg2_val,
                                          int copy);

#ifdef __cplusplus
}
#endif

// Records a pair of begin and end events called "name" for the current
// scope, with 0, 1 or 2 associated arguments. If the category is not
// enabled, then this does nothing.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
#define CEF_TRACE_EVENT0(category, name) \
  cef_trace_event(category, name, NULL, 0, NULL, 0)
#define CEF_TRACE_EVENT1(category, name, arg1_name, arg1_val) \
  cef_trace_event(category, name, arg1_name, arg1_val, NULL, 0)
#define CEF_TRACE_EVENT2(category, name, arg1_name, arg1_val, arg2_name, \
      arg2_val) \
  cef_trace_event(category, name, arg1_name, arg1_val, arg2_name, arg2_val)

// Records a single event called "name" immediately, with 0, 1 or 2
// associated arguments. If the category is not enabled, then this
// does nothing.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
#define CEF_TRACE_EVENT_INSTANT0(category, name) \
  cef_trace_event_instant(category, name, NULL, 0, NULL, 0, false)
#define CEF_TRACE_EVENT_INSTANT1(category, name, arg1_name, arg1_val) \
  cef_trace_event_instant(category, name, arg1_name, arg1_val, NULL, 0, false)
#define CEF_TRACE_EVENT_INSTANT2(category, name, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_instant(category, name, arg1_name, arg1_val, arg2_name, \
      arg2_val, false)
#define CEF_TRACE_EVENT_COPY_INSTANT0(category, name) \
  cef_trace_event_instant(category, name, NULL, 0, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_INSTANT1(category, name, arg1_name, arg1_val) \
  cef_trace_event_instant(category, name, arg1_name, arg1_val, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_INSTANT2(category, name, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_instant(category, name, arg1_name, arg1_val, arg2_name, \
      arg2_val, true)

// Records a single BEGIN event called "name" immediately, with 0, 1 or 2
// associated arguments. If the category is not enabled, then this
// does nothing.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
#define CEF_TRACE_EVENT_BEGIN0(category, name) \
  cef_trace_event_begin(category, name, NULL, 0, NULL, 0, false)
#define CEF_TRACE_EVENT_BEGIN1(category, name, arg1_name, arg1_val) \
  cef_trace_event_begin(category, name, arg1_name, arg1_val, NULL, 0, false)
#define CEF_TRACE_EVENT_BEGIN2(category, name, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_begin(category, name, arg1_name, arg1_val, arg2_name, \
      arg2_val, false)
#define CEF_TRACE_EVENT_COPY_BEGIN0(category, name) \
  cef_trace_event_begin(category, name, NULL, 0, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_BEGIN1(category, name, arg1_name, arg1_val) \
  cef_trace_event_begin(category, name, arg1_name, arg1_val, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_BEGIN2(category, name, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_begin(category, name, arg1_name, arg1_val, arg2_name, \
      arg2_val, true)

// Records a single END event for "name" immediately. If the category
// is not enabled, then this does nothing.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
#define CEF_TRACE_EVENT_END0(category, name) \
  cef_trace_event_end(category, name, NULL, 0, NULL, 0, false)
#define CEF_TRACE_EVENT_END1(category, name, arg1_name, arg1_val) \
  cef_trace_event_end(category, name, arg1_name, arg1_val, NULL, 0, false)
#define CEF_TRACE_EVENT_END2(category, name, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_end(category, name, arg1_name, arg1_val, arg2_name, \
      arg2_val, false)
#define CEF_TRACE_EVENT_COPY_END0(category, name) \
  cef_trace_event_end(category, name, NULL, 0, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_END1(category, name, arg1_name, arg1_val) \
  cef_trace_event_end(category, name, arg1_name, arg1_val, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_END2(category, name, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_end(category, name, arg1_name, arg1_val, arg2_name, \
      arg2_val, true)

// Time threshold event:
// Only record the event if the duration is greater than the specified
// threshold_us (time in microseconds).
// Records a pair of begin and end events called "name" for the current
// scope, with 0, 1 or 2 associated arguments. If the category is not
// enabled, then this does nothing.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
#define CEF_TRACE_EVENT_IF_LONGER_THAN0(threshold_us, category, name) \
  cef_trace_event_if_longer_than(threshold_us, category, name, NULL, 0, NULL, 0)
#define CEF_TRACE_EVENT_IF_LONGER_THAN1(threshold_us, category, name, \
      arg1_name, arg1_val) \
  cef_trace_event_if_longer_than(threshold_us, category, name, arg1_name, \
      arg1_val, NULL, 0)
#define CEF_TRACE_EVENT_IF_LONGER_THAN2(threshold_us, category, name, \
      arg1_name, arg1_val, arg2_name, arg2_val) \
  cef_trace_event_if_longer_than(threshold_us, category, name, arg1_name, \
      arg1_val, arg2_name, arg2_val)

// Records the value of a counter called "name" immediately. Value
// must be representable as a 32 bit integer.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
#define CEF_TRACE_COUNTER1(category, name, value) \
  cef_trace_counter(category, name, NULL, value, NULL, 0, false)
#define CEF_TRACE_COPY_COUNTER1(category, name, value) \
  cef_trace_counter(category, name, NULL, value, NULL, 0, true)

// Records the values of a multi-parted counter called "name" immediately.
// The UI will treat value1 and value2 as parts of a whole, displaying their
// values as a stacked-bar chart.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
#define CEF_TRACE_COUNTER2(category, name, value1_name, value1_val, \
      value2_name, value2_val) \
  cef_trace_counter(category, name, value1_name, value1_val, value2_name, \
      value2_val, false)
#define CEF_TRACE_COPY_COUNTER2(category, name, value1_name, value1_val, \
      value2_name, value2_val) \
  cef_trace_counter(category, name, value1_name, value1_val, value2_name, \
      value2_val, true)

// Records the value of a counter called "name" immediately. Value
// must be representable as a 32 bit integer.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
// - |id| is used to disambiguate counters with the same name. It must either
//   be a pointer or an integer value up to 64 bits. If it's a pointer, the
//   bits will be xored with a hash of the process ID so that the same pointer
//   on two different processes will not collide.
#define CEF_TRACE_COUNTER_ID1(category, name, id, value) \
  cef_trace_counter_id(category, name, id, NULL, value, NULL, 0, false)
#define CEF_TRACE_COPY_COUNTER_ID1(category, name, id, value) \
  cef_trace_counter_id(category, name, id, NULL, value, NULL, 0, true)

// Records the values of a multi-parted counter called "name" immediately.
// The UI will treat value1 and value2 as parts of a whole, displaying their
// values as a stacked-bar chart.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
// - |id| is used to disambiguate counters with the same name. It must either
//   be a pointer or an integer value up to 64 bits. If it's a pointer, the
//   bits will be xored with a hash of the process ID so that the same pointer
//   on two different processes will not collide.
#define CEF_TRACE_COUNTER_ID2(category, name, id, value1_name, value1_val, \
      value2_name, value2_val) \
  cef_trace_counter_id(category, name, id, value1_name, value1_val, \
      value2_name, value2_val, false)
#define CEF_TRACE_COPY_COUNTER_ID2(category, name, id, value1_name, \
      value1_val, value2_name, value2_val) \
  cef_trace_counter_id(category, name, id, value1_name, value1_val, \
      value2_name, value2_val, true)


// Records a single ASYNC_BEGIN event called "name" immediately, with 0, 1 or 2
// associated arguments. If the category is not enabled, then this
// does nothing.
// - category and name strings must have application lifetime (statics or
//   literals). They may not include " chars.
// - |id| is used to match the ASYNC_BEGIN event with the ASYNC_END event.
//   ASYNC events are considered to match if their category, name and id values
//   all match. |id| must either be a pointer or an integer value up to 64
//   bits. If it's a pointer, the bits will be xored with a hash of the process
//   ID sothat the same pointer on two different processes will not collide.
// An asynchronous operation can consist of multiple phases. The first phase is
// defined by the ASYNC_BEGIN calls. Additional phases can be defined using the
// ASYNC_STEP_BEGIN macros. When the operation completes, call ASYNC_END.
// An async operation can span threads and processes, but all events in that
// operation must use the same |name| and |id|. Each event can have its own
// args.
#define CEF_TRACE_EVENT_ASYNC_BEGIN0(category, name, id) \
  cef_trace_event_async_begin(category, name, id, NULL, 0, NULL, 0, false)
#define CEF_TRACE_EVENT_ASYNC_BEGIN1(category, name, id, arg1_name, arg1_val) \
  cef_trace_event_async_begin(category, name, id, arg1_name, arg1_val, NULL, \
      0, false)
#define CEF_TRACE_EVENT_ASYNC_BEGIN2(category, name, id, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_async_begin(category, name, id, arg1_name, arg1_val, \
      arg2_name, arg2_val, false)
#define CEF_TRACE_EVENT_COPY_ASYNC_BEGIN0(category, name, id) \
  cef_trace_event_async_begin(category, name, id, NULL, 0, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_ASYNC_BEGIN1(category, name, id, arg1_name, \
      arg1_val) \
  cef_trace_event_async_begin(category, name, id, arg1_name, arg1_val, NULL, \
      0, true)
#define CEF_TRACE_EVENT_COPY_ASYNC_BEGIN2(category, name, id, arg1_name, \
      arg1_val, arg2_name, arg2_val) \
  cef_trace_event_async_begin(category, name, id, arg1_name, arg1_val, \
      arg2_name, arg2_val, true)

// Records a single ASYNC_STEP event for |step| immediately. If the category
// is not enabled, then this does nothing. The |name| and |id| must match the
// ASYNC_BEGIN event above. The |step| param identifies this step within the
// async event. This should be called at the beginning of the next phase of an
// asynchronous operation.
#define CEF_TRACE_EVENT_ASYNC_STEP0(category, name, id, step) \
  cef_trace_event_async_step(category, name, id, step, NULL, 0, false)
#define CEF_TRACE_EVENT_ASYNC_STEP1(category, name, id, step, \
      arg1_name, arg1_val) \
  cef_trace_event_async_step(category, name, id, step, arg1_name, arg1_val, \
      false)
#define CEF_TRACE_EVENT_COPY_ASYNC_STEP0(category, name, id, step) \
  cef_trace_event_async_step(category, name, id, step, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_ASYNC_STEP1(category, name, id, step, \
      arg1_name, arg1_val) \
  cef_trace_event_async_step(category, name, id, step, arg1_name, arg1_val, \
      true)

// Records a single ASYNC_END event for "name" immediately. If the category
// is not enabled, then this does nothing.
#define CEF_TRACE_EVENT_ASYNC_END0(category, name, id) \
  cef_trace_event_async_end(category, name, id, NULL, 0, NULL, 0, false)
#define CEF_TRACE_EVENT_ASYNC_END1(category, name, id, arg1_name, arg1_val) \
  cef_trace_event_async_end(category, name, id, arg1_name, arg1_val, NULL, 0, \
      false)
#define CEF_TRACE_EVENT_ASYNC_END2(category, name, id, arg1_name, arg1_val, \
      arg2_name, arg2_val) \
  cef_trace_event_async_end(category, name, id, arg1_name, arg1_val, \
      arg2_name, arg2_val, false)
#define CEF_TRACE_EVENT_COPY_ASYNC_END0(category, name, id) \
  cef_trace_event_async_end(category, name, id, NULL, 0, NULL, 0, true)
#define CEF_TRACE_EVENT_COPY_ASYNC_END1(category, name, id, arg1_name, \
      arg1_val) \
  cef_trace_event_async_end(category, name, id, arg1_name, arg1_val, NULL, 0, \
      true)
#define CEF_TRACE_EVENT_COPY_ASYNC_END2(category, name, id, arg1_name, \
      arg1_val, arg2_name, arg2_val) \
  cef_trace_event_async_end(category, name, id, arg1_name, arg1_val, \
      arg2_name, arg2_val, true)

#endif  // CEF_INCLUDE_CEF_TRACE_EVENT_H_
