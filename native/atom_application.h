#include "include/cef_app.h"
#include "include/cef_application_mac.h"

class AtomCefClient;

@interface AtomApplication : NSApplication <CefAppProtocol, NSApplicationDelegate> {
@private
  NSWindowController *_backgroundWindowController;
  
  BOOL handlingSendEvent_;
}

+ (CefSettings)createCefSettings;
- (void)open:(NSString *)path;
- (IBAction)runSpecs:(id)sender;
- (IBAction)runBenchmarks:(id)sender;

@end