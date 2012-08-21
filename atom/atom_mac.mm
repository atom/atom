#import "include/cef_application_mac.h"
#import "atom/client_handler.h"
#import "atom/atom_mac.h"
#import "atom/atom_controller.h"

@implementation Atom

+ (id)sharedApplication {
  id atomApp = [super sharedApplication];
  
  CefSettings settings;
  [self populateAppSettings:settings];
  
  CefMainArgs mainArgs(0, NULL);
  CefRefPtr<CefApp> app;

  CefInitialize(mainArgs, settings, app.get());
  
  return atomApp;
}
   
+ (void)populateAppSettings:(CefSettings &)settings {
  CefString(&settings.cache_path) = "";
  CefString(&settings.user_agent) = "";
  CefString(&settings.log_file) = "";
  CefString(&settings.javascript_flags) = "";
 
  settings.log_severity = LOGSEVERITY_ERROR;
}


// Create the application on the UI thread.
- (void)createWindow {
  AtomController *controller = [[AtomController alloc] init];
}

# pragma mark NSApplicationDelegate

// Sent by the default notification center immediately before the application terminates.
- (void)applicationWillTerminate:(NSNotification *)notification {  
  CefShutdown();
  [self release];
}

# pragma mark CefAppProtocol

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

@end