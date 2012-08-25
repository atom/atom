#include "include/cef_app.h"

class AtomCefClient;

@interface AtomApplication : NSApplication <CefAppProtocol, NSApplicationDelegate> {
@private
  NSWindow *_backgroundWindow;
	
  CefRefPtr<AtomCefClient> _cefClient;
	
  BOOL handlingSendEvent_;
}

+ (void)populateAppSettings:(CefSettings &)settings;
- (void)open:(NSString *)path;
- (IBAction)runSpecs:(id)sender;
- (IBAction)runBenchmarks:(id)sender;

@end