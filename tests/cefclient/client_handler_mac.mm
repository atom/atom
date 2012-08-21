// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>

#include "cefclient/client_handler.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"

#ifndef PROCESS_HELPER_APP
CefRefPtr<ClientHandler> g_handler;
#endif

void ClientHandler::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    const CefString& url) {
  REQUIRE_UI_THREAD();
}

void ClientHandler::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                  const CefString& title) {
  REQUIRE_UI_THREAD();
}

void ClientHandler::CloseMainWindow() {
  NSWindow* window = nil;
#ifndef PROCESS_HELPER_APP
  if (g_handler.get()) window = (NSWindow *)g_handler->GetMainHwnd();
#endif
  
  [window performSelectorOnMainThread:@selector(close) withObject:nil waitUntilDone:NO];
}

std::string ClientHandler::GetDownloadPath(const std::string& file_name) {
  return std::string();
}
