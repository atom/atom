#import <AppKit/AppKit.h>
#import "include/cef_browser.h"
#import "include/cef_frame.h"
#import "native/atom_cef_client.h"
#import "atom_application.h"

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
  replyArguments->SetSize(2);
  replyArguments->SetInt(0, replyId);
  replyArguments->SetInt(1, clickedButtonTag);
  browser->SendProcessMessage(PID_RENDERER, replyMessage);
}
