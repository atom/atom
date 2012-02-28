#import "include/cef.h"
#import "include/cef_application_mac.h"

class ClientHandler;

@class AtomController;

@interface Atom : NSApplication<CefAppProtocol> {
  NSView *_hiddenGlobalView;
  BOOL handlingSendEvent_;
  CefRefPtr<ClientHandler> _globalHandler;
}

- (void)open:(NSString *)path;
- (IBAction)runSpecs:(id)sender;

@end

// Returns the application settings based on command line arguments.
void AppGetSettings(CefSettings& settings);
