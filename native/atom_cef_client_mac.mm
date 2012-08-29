#import <AppKit/AppKit.h>
#import "include/cef_browser.h"
#import "include/cef_frame.h"
#import "native/atom_cef_client.h"
#import "atom_application.h"
#import "atom_window_controller.h"

void AtomCefClient::Open(std::string path) {
  NSString *pathString = [NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding];
  [(AtomApplication *)[AtomApplication sharedApplication] open:pathString];
}

void AtomCefClient::Open() {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:YES];
  if ([panel runModal] == NSFileHandlingPanelOKButton) {
    NSURL *url = [[panel URLs] lastObject];
    Open([[url path] UTF8String]);
  }
}

void AtomCefClient::NewWindow() {
  [(AtomApplication *)[AtomApplication sharedApplication] open:nil];
}

void AtomCefClient::ToggleDevTools(CefRefPtr<CefBrowser> browser) {
  AtomWindowController *windowController = [[browser->GetHost()->GetWindowHandle() window] windowController];
  [windowController toggleDevTools];
}
