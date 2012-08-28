#import "include/cef_application_mac.h"
#import "native/atom_cef_client.h"
#import "native/atom_application.h"
#import "native/atom_window_controller.h"
#import "native/atom_cef_app.h"

@implementation AtomApplication

+ (id)sharedApplication {
  NSApplication *application = [super sharedApplication];
  CefInitialize(CefMainArgs(0, NULL), [self createCefSettings], new AtomCefApp);
  return application;
}

+ (CefSettings)createCefSettings {
  CefSettings settings;
  CefString(&settings.cache_path) = "";
  CefString(&settings.user_agent) = "";
  CefString(&settings.log_file) = "";
  CefString(&settings.javascript_flags) = "";
  settings.remote_debugging_port = 9090;
  settings.log_severity = LOGSEVERITY_ERROR;
  return settings;
}

- (void)dealloc {
  [_backgroundWindowController release];
  [super dealloc];
}

- (void)open:(NSString *)path {
  [[AtomWindowController alloc] initWithPath:path];
}

- (IBAction)runSpecs:(id)sender {
  [[AtomWindowController alloc] initSpecs];
}

- (IBAction)runBenchmarks:(id)sender {
  [[AtomWindowController alloc] initBenchmarks];
}

//#pragma mark BrowserDelegate
//
//- (void)loadEnd {
//  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--headless"]) {
//    [self modifyJavaScript:^(CefRefPtr<CefV8Context> context, CefRefPtr<CefV8Value> global) {
//      CefRefPtr<CefV8Value> atom = context->GetGlobal()->GetValue("atom");
//      atom->SetValue("headless", CefV8Value::CreateBool(YES), V8_PROPERTY_ATTRIBUTE_NONE);
//    }];
//  }
//
//  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--benchmark"]) {
//    [self runBenchmarks:self];
//  }
//
//  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--test"]) {
//    [self runSpecs:self];
//  }
//}
//

# pragma mark NSApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  _backgroundWindowController = [[AtomWindowController alloc] initInBackground];
  [self open:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  CefShutdown();
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
  if ([[self mainMenu] performKeyEquivalent:event]) return;
  
  if (_backgroundWindowController && ![self keyWindow] && [event type] == NSKeyDown) {
    [_backgroundWindowController.window makeKeyWindow];
    [_backgroundWindowController.window sendEvent:event];
  }
  else {
    [super sendEvent:event];
  }
}

@end
