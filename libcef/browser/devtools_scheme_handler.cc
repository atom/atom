// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/devtools_scheme_handler.h"

#include <string>

#include "include/cef_browser.h"
#include "include/cef_request.h"
#include "include/cef_resource_handler.h"
#include "include/cef_response.h"
#include "include/cef_scheme.h"
#include "include/cef_stream.h"
#include "include/cef_url.h"

#include "base/file_util.h"
#include "base/string_util.h"
#include "content/public/common/content_client.h"
#include "grit/devtools_resources_map.h"
#include "ui/base/resource/resource_bundle.h"

const char kChromeDevToolsScheme[] = "chrome-devtools";
const char kChromeDevToolsHost[] = "devtools";
const char kChromeDevToolsURL[] = "chrome-devtools://devtools/";

namespace {

static std::string PathWithoutParams(const std::string& path) {
  size_t query_position = path.find("?");
  if (query_position != std::string::npos)
    return path.substr(0, query_position);
  return path;
}

static std::string GetMimeType(const std::string& filename) {
  if (EndsWith(filename, ".html", false)) {
    return "text/html";
  } else if (EndsWith(filename, ".css", false)) {
    return "text/css";
  } else if (EndsWith(filename, ".js", false)) {
    return "application/javascript";
  } else if (EndsWith(filename, ".png", false)) {
    return "image/png";
  } else if (EndsWith(filename, ".gif", false)) {
    return "image/gif";
  }
  NOTREACHED();
  return "text/plain";
}

class DevToolsSchemeHandler : public CefResourceHandler {
 public:
  DevToolsSchemeHandler(const std::string& path,
                        CefRefPtr<CefStreamReader> reader,
                        int size)
    : path_(path), reader_(reader), size_(size) {
  }

  virtual bool ProcessRequest(CefRefPtr<CefRequest> request,
                              CefRefPtr<CefCallback> callback)
                              OVERRIDE {
    callback->Continue();
    return true;
  }

  virtual void GetResponseHeaders(CefRefPtr<CefResponse> response,
                                  int64& response_length,
                                  CefString& redirectUrl) OVERRIDE {
    response_length = size_;

    response->SetMimeType(GetMimeType(path_));
    response->SetStatus(200);
  }

  virtual bool ReadResponse(void* data_out,
                            int bytes_to_read,
                            int& bytes_read,
                            CefRefPtr<CefCallback> callback)
                            OVERRIDE {
    bytes_read = reader_->Read(data_out, 1, bytes_to_read);
    return (bytes_read > 0);
  }

  virtual void Cancel() OVERRIDE {
  }

 private:
  std::string path_;
  CefRefPtr<CefStreamReader> reader_;
  int size_;

  IMPLEMENT_REFCOUNTING(DevToolSSchemeHandler);
};

class DevToolsSchemeHandlerFactory : public CefSchemeHandlerFactory {
 public:
  DevToolsSchemeHandlerFactory() {}

  virtual CefRefPtr<CefResourceHandler> Create(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      const CefString& scheme_name,
      CefRefPtr<CefRequest> request) OVERRIDE {
    std::string url = PathWithoutParams(request->GetURL());
    const char* path = &url.c_str()[strlen(kChromeDevToolsURL)];

    int size = -1;
    CefRefPtr<CefStreamReader> reader = GetStreamReader(path, size);
    if (!reader.get())
      return NULL;

    return new DevToolsSchemeHandler(path, reader, size);
  }

  CefRefPtr<CefStreamReader> GetStreamReader(const char* path, int& size) {
    // Create a stream for the grit resource.
    for (size_t i = 0; i < kDevtoolsResourcesSize; ++i) {
      if (base::strcasecmp(kDevtoolsResources[i].name, path) == 0) {
        base::StringPiece piece =
            content::GetContentClient()->GetDataResource(
                kDevtoolsResources[i].value, ui::SCALE_FACTOR_NONE);
        if (!piece.empty()) {
          size = piece.size();
          return CefStreamReader::CreateForData(const_cast<char*>(piece.data()),
                                                size);
        }
      }
    }

    NOTREACHED() << "Missing DevTools resource: " << path;
    return NULL;
  }

  IMPLEMENT_REFCOUNTING(DevToolSSchemeHandlerFactory);
};

}  // namespace

// Register the DevTools scheme handler.
void RegisterDevToolsSchemeHandler() {
  CefRegisterSchemeHandlerFactory(kChromeDevToolsScheme, kChromeDevToolsHost,
                                  new DevToolsSchemeHandlerFactory());
}
