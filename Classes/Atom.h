#import "include/cef.h"
#import "include/cef_application_mac.h"

@class AtomController;

@interface Atom : NSApplication<CefAppProtocol> {
  BOOL handlingSendEvent_;
}

- (IBAction)runSpecs:(id)sender;

@end

// Returns the application settings based on command line arguments.
void AppGetSettings(CefSettings& settings);
