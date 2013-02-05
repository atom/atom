#import <AppKit/AppKit.h>
#import <iostream>
#import "include/cef_browser.h"
#import "include/cef_frame.h"
#import "native/atom_cef_client.h"
#import "atom_application.h"
#import "atom_window_controller.h"

void AtomCefClient::FocusNextWindow() {
  NSArray *windows = [NSApp windows];
  int count = [windows count];
  int start = [windows indexOfObject:[NSApp keyWindow]];

  int i = start;
  while (true) {
    i = (i + 1) % count;
    if (i == start) break;
    NSWindow *window = [windows objectAtIndex:i];
    if ([window isVisible] && ![window isExcludedFromWindowsMenu]) {
      [window makeKeyAndOrderFront:nil];
      break;
    }
  }
}

void AtomCefClient::FocusPreviousWindow() {
  NSArray *windows = [NSApp windows];
  int count = [windows count];
  int start = [windows indexOfObject:[NSApp keyWindow]];

  int i = start;
  while (true) {
    i = i - 1;
    if (i == 0) i = count -1;
    if (i == start) break;
    NSWindow *window = [windows objectAtIndex:i];
    if ([window isVisible] && ![window isExcludedFromWindowsMenu]) {
      [window makeKeyAndOrderFront:nil];
      break;
    }
  }
}

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

void AtomCefClient::OpenUnstable(std::string path) {
  NSString *pathString = [NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding];
  [(AtomApplication *)[AtomApplication sharedApplication] openUnstable:pathString];
}

void AtomCefClient::OpenUnstable() {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:YES];
  if ([panel runModal] == NSFileHandlingPanelOKButton) {
    NSURL *url = [[panel URLs] lastObject];
    OpenUnstable([[url path] UTF8String]);
  }
}

void AtomCefClient::NewWindow() {
  [(AtomApplication *)[AtomApplication sharedApplication] open:nil];
}

void AtomCefClient::Confirm(int replyId,
                            std::string message,
                            std::string detailedMessage,
                            std::vector<std::string> buttonLabels,
                            CefRefPtr<CefBrowser> browser) {
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  [alert setMessageText:[NSString stringWithCString:message.c_str() encoding:NSUTF8StringEncoding]];
  [alert setInformativeText:[NSString stringWithCString:detailedMessage.c_str() encoding:NSUTF8StringEncoding]];

  for (int i = 0; i < buttonLabels.size(); i++) {
    NSString *title = [NSString stringWithCString:buttonLabels[i].c_str() encoding:NSUTF8StringEncoding];
    NSButton *button = [alert addButtonWithTitle:title];
    [button setTag:i];
  }

  NSUInteger clickedButtonTag = [alert runModal];

  CefRefPtr<CefProcessMessage> replyMessage = CefProcessMessage::Create("reply");
  CefRefPtr<CefListValue> replyArguments = replyMessage->GetArgumentList();
  replyArguments->SetSize(1);
  replyArguments->SetList(0, CreateReplyDescriptor(replyId, clickedButtonTag));
  browser->SendProcessMessage(PID_RENDERER, replyMessage);
}


void AtomCefClient::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) {
  NSWindow *window = [browser->GetHost()->GetWindowHandle() window];
  [window setTitle:[NSString stringWithUTF8String:title.ToString().c_str()]];
}

void AtomCefClient::ToggleDevTools(CefRefPtr<CefBrowser> browser) {
  AtomWindowController *windowController = [[browser->GetHost()->GetWindowHandle() window] windowController];
  [windowController toggleDevTools];
}

void AtomCefClient::ShowDevTools(CefRefPtr<CefBrowser> browser) {
  AtomWindowController *windowController = [[browser->GetHost()->GetWindowHandle() window] windowController];
  [windowController showDevTools];
}

void AtomCefClient::Show(CefRefPtr<CefBrowser> browser) {
  AtomWindowController *windowController = [[browser->GetHost()->GetWindowHandle() window] windowController];
  [windowController.webView setHidden:NO];
}

void AtomCefClient::ToggleFullScreen(CefRefPtr<CefBrowser> browser) {
  [[browser->GetHost()->GetWindowHandle() window] toggleFullScreen:nil];
}

void AtomCefClient::ShowSaveDialog(int replyId, CefRefPtr<CefBrowser> browser) {
  CefRefPtr<CefProcessMessage> replyMessage = CefProcessMessage::Create("reply");
  CefRefPtr<CefListValue> replyArguments = replyMessage->GetArgumentList();

  NSSavePanel *panel = [NSSavePanel savePanel];
  if ([panel runModal] == NSFileHandlingPanelOKButton) {
    CefString path = CefString([[[panel URL] path] UTF8String]);
    replyArguments->SetSize(2);
    replyArguments->SetString(1, path);
  }
  else {
    replyArguments->SetSize(1);
  }
  replyArguments->SetList(0, CreateReplyDescriptor(replyId, 0));

  browser->SendProcessMessage(PID_RENDERER, replyMessage);
}

CefRefPtr<CefListValue> AtomCefClient::CreateReplyDescriptor(int replyId, int callbackIndex) {
  CefRefPtr<CefListValue> descriptor = CefListValue::Create();
  descriptor->SetSize(2);
  descriptor->SetInt(0, replyId);
  descriptor->SetInt(1, callbackIndex);
  return descriptor;
}

void AtomCefClient::Exit(int status) {
  exit(status);
}

void AtomCefClient::Log(const char *message) {
  std::cout << message << "\n";
}
