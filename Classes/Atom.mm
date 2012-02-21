#import "Atom.h"
#import "include/cef.h"
#import "AtomController.h"

// Provide the CefAppProtocol implementation required by CEF.
@implementation Atom

+ (NSApplication *)sharedApplication {
  // Populate the settings based on command line arguments.
  CefSettings settings;
  AppGetSettings(settings);
  
  // Initialize CEF.
  CefRefPtr<CefApp> app;
  CefInitialize(settings, app);
  
  return [super sharedApplication];  
}

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent sendingEventScoper;
  [super sendEvent:event];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {

}

- (IBAction)runSpecs:(id)sender {
  [[AtomController alloc] initForSpecs];
}

// Sent by the default notification center immediately before the application terminates.
- (void)applicationWillTerminate:(NSNotification *)aNotification {
  CefShutdown();
  [self release];
}

@end
  
// Returns the application settings based on command line arguments.
void AppGetSettings(CefSettings& settings) {  
  CefString(&settings.cache_path) = "";
  CefString(&settings.user_agent) = "";
  CefString(&settings.product_version) = "";
  CefString(&settings.locale) = "";
  CefString(&settings.log_file) = "";
  CefString(&settings.javascript_flags) = "";
  
  settings.log_severity = LOGSEVERITY_ERROR;
  settings.local_storage_quota = 0;
  settings.session_storage_quota = 0;
}
