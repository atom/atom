// Copyright (c) 2012 Marshall A. Greenblatt. Portons copyright (c) 2012
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
//
// ---------------------------------------------------------------------------
//
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//

// See cef_trace_event.h for trace macros and additonal documentation.

#ifndef CEF_INCLUDE_CEF_TRACE_H_
#define CEF_INCLUDE_CEF_TRACE_H_
#pragma once

#include "include/cef_base.h"

///
// Implement this interface to receive trace notifications. The methods of this
// class will be called on the browser process UI thread.
///
/*--cef(source=client)--*/
class CefTraceClient : public virtual CefBase {
 public:
  ///
  // Called 0 or more times between CefBeginTracing and OnEndTracingComplete
  // with a UTF8 JSON |fragment| of the specified |fragment_size|. Do not keep
  // a reference to |fragment|.
  ///
  /*--cef()--*/
  virtual void OnTraceDataCollected(const char* fragment,
                                    size_t fragment_size) {}

  ///
  // Called in response to CefGetTraceBufferPercentFullAsync.
  ///
  /*--cef()--*/
  virtual void OnTraceBufferPercentFullReply(float percent_full) {}

  ///
  // Called after all processes have sent their trace data.
  ///
  /*--cef()--*/
  virtual void OnEndTracingComplete() {}
};


///
// Start tracing events on all processes. Tracing begins immediately locally,
// and asynchronously on child processes as soon as they receive the
// BeginTracing request.
//
// If CefBeginTracing was called previously, or if a CefEndTracingAsync call is
// pending, CefBeginTracing will fail and return false.
//
// |categories| is a comma-delimited list of category wildcards. A category can
// have an optional '-' prefix to make it an excluded category. Having both
// included and excluded categories in the same list is not supported.
//
// Example: "test_MyTest*"
// Example: "test_MyTest*,test_OtherStuff"
// Example: "-excluded_category1,-excluded_category2"
//
// This function must be called on the browser process UI thread.
///
/*--cef(optional_param=client,optional_param=categories)--*/
bool CefBeginTracing(CefRefPtr<CefTraceClient> client,
                     const CefString& categories);

///
// Get the maximum trace buffer percent full state across all processes.
//
// CefTraceClient::OnTraceBufferPercentFullReply will be called asynchronously
// after the value is determibed. When any child process reaches 100% full
// tracing will end automatically and CefTraceClient::OnEndTracingComplete
// will be called. This function fails and returns false if trace is ending or
// disabled, no CefTraceClient was passed to CefBeginTracing, or if a previous
// call to CefGetTraceBufferPercentFullAsync is pending.
//
// This function must be called on the browser process UI thread.
///
/*--cef()--*/
bool CefGetTraceBufferPercentFullAsync();

///
// Stop tracing events on all processes.
//
// This function will fail and return false if a previous call to
// CefEndTracingAsync is already pending or if CefBeginTracing was not called.
//
// This function must be called on the browser process UI thread.
///
/*--cef()--*/
bool CefEndTracingAsync();

#endif  // CEF_INCLUDE_CEF_TRACE_H_
