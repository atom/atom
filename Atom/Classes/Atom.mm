#import "Atom.h"
#import "include/cef.h"
#import "AtomController.h"

#import "client_handler.h"

// Provide the CefAppProtocol implementation required by CEF.
@implementation Atom

+ (NSApplication *)sharedApplication {
  if (!NSApp) {
    // Populate the settings based on command line arguments.
    CefSettings settings;
    AppGetSettings(settings);
    
    // Initialize CEF.
    CefRefPtr<CefApp> app;
    CefInitialize(settings, app);
  }
  
  return [super sharedApplication];  
}

- (void)dealloc {
  [_hiddenGlobalView release];
  [self dealloc];
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

- (void)createGlobalContext {
  _globalHandler = new ClientHandler(self);
  
  CefWindowInfo window_info;
  _hiddenGlobalView = [[NSView alloc] init];
  window_info.SetAsChild(_hiddenGlobalView, 0, 0, 0, 0);

  CefBrowserSettings settings;  
  CefBrowser::CreateBrowser(window_info, _globalHandler.get(), "", settings);
}

- (void)open:(NSString *)path {
  
}

- (IBAction)runSpecs:(id)sender {
  CefRefPtr<CefV8Context> appContext = _globalHandler->GetBrowser()->GetMainFrame()->GetV8Context();
  [[AtomController alloc] initSpecsWithAppContext:appContext];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  [self createGlobalContext];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  CefShutdown();
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
