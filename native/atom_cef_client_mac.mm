#import <AppKit/AppKit.h>
#import "include/cef_browser.h"
#import "include/cef_frame.h"
#import "native/atom_cef_client.h"
#import "atom_application.h"

void AtomCefClient::Open(std::string path) {
  NSString *pathString = [NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding];
  [(AtomApplication *)[AtomApplication sharedApplication] open:pathString];
}