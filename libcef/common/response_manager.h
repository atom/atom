// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_LIBCEF_COMMON_RESPONSE_MANAGER_H_
#define CEF_LIBCEF_COMMON_RESPONSE_MANAGER_H_
#pragma once

#include <map>
#include "include/cef_base.h"
#include "base/threading/non_thread_safe.h"

struct Cef_Response_Params;

// This class is not thread-safe.
class CefResponseManager : base::NonThreadSafe {
 public:
  // Used for handling response messages.
  class Handler : public virtual CefBase {
   public:
     virtual void OnResponse(const Cef_Response_Params& params) =0;
  };

  // Used for handling response ack messages.
  class AckHandler : public virtual CefBase {
   public:
     virtual void OnResponseAck() =0;
  };

  CefResponseManager();

  // Returns the next unique request id.
  int GetNextRequestId();

  // Register a response handler and return the unique request id.
  int RegisterHandler(CefRefPtr<Handler> handler);

  // Run the response handler for the specified request id. Returns true if a
  // handler was run.
  bool RunHandler(const Cef_Response_Params& params);

  // Register a response ack handler for the specified request id.
  void RegisterAckHandler(int request_id, CefRefPtr<AckHandler> handler);

  // Run the response ack handler for the specified request id. Returns true if
  // a handler was run.
  bool RunAckHandler(int request_id);

 private:
  // Used for generating unique request ids.
  int next_request_id_;

  // Map of unique request ids to Handler references.
  typedef std::map<int, CefRefPtr<Handler> > HandlerMap;
  HandlerMap handlers_;

  // Map of unique request ids to AckHandler references.
  typedef std::map<int, CefRefPtr<AckHandler> > AckHandlerMap;
  AckHandlerMap ack_handlers_;
};

#endif  // CEF_LIBCEF_COMMON_RESPONSE_MANAGER_H_
