#import <AppKit/AppKit.h>
#import "include/cef_browser.h"
#import "include/cef_frame.h"
#import "atom/client_handler.h"

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
