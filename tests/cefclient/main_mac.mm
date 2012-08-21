#import <Cocoa/Cocoa.h>
#include <sstream>
#include "include/cef_app.h"
#import "include/cef_application_mac.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_runnable.h"
#include "cefclient/client_handler.h"
#include "cefclient/cefclient_mac.h"

int main(int argc, char* argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  CefMainArgs mainArgs(argc, argv);
  CefRefPtr<CefApp> app;
  
  int exit_code = CefExecuteProcess(mainArgs, app.get());
  if (exit_code >= 0){
    return exit_code;
  }

  NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
  ClientApplication *application = (ClientApplication *)[ClientApplication sharedApplication];
  
  NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
  NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
  [mainNib instantiateNibWithOwner:application topLevelObjects:nil];  // Execute the secondary process, if any.
  
  [application createWindow];
  
  // Run the application message loop.
  CefRunMessageLoop();

  [pool release];
  
  // Don't put anything below this line because it won't be executed.
  return 0;
 }