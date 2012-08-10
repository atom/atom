// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/wrapper/cef_stream_resource_handler.h"
#include "include/cef_callback.h"
#include "include/cef_request.h"
#include "include/cef_stream.h"
#include "libcef_dll/cef_logging.h"

CefStreamResourceHandler::CefStreamResourceHandler(
    const CefString& mime_type,
    CefRefPtr<CefStreamReader> stream)
    : status_code_(200),
      mime_type_(mime_type),
      stream_(stream) {
  DCHECK(!mime_type_.empty());
  DCHECK(stream_.get());
}

CefStreamResourceHandler::CefStreamResourceHandler(
    int status_code,
    const CefString& mime_type,
    CefResponse::HeaderMap header_map,
    CefRefPtr<CefStreamReader> stream)
    : status_code_(status_code),
      mime_type_(mime_type),
      header_map_(header_map),
      stream_(stream) {
  DCHECK(!mime_type_.empty());
  DCHECK(stream_.get());
}

bool CefStreamResourceHandler::ProcessRequest(CefRefPtr<CefRequest> request,
                                              CefRefPtr<CefCallback> callback) {
  callback->Continue();
  return true;
}

void CefStreamResourceHandler::GetResponseHeaders(
    CefRefPtr<CefResponse> response,
    int64& response_length,
    CefString& redirectUrl) {
  response->SetStatus(status_code_);
  response->SetMimeType(mime_type_);

  if (!header_map_.empty())
    response->SetHeaderMap(header_map_);

  response_length = -1;
}

bool CefStreamResourceHandler::ReadResponse(void* data_out,
                                            int bytes_to_read,
                                            int& bytes_read,
                                            CefRefPtr<CefCallback> callback) {
  bytes_read = stream_->Read(data_out, 1, bytes_to_read);
  return (bytes_read > 0);
}

void CefStreamResourceHandler::Cancel() {
}
