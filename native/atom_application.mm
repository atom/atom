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

+ (NSString *)supportDirectory {
  NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  NSString *executableName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
  NSString *supportDirectory = [cachePath stringByAppendingPathComponent:executableName];

  NSFileManager *fs = [NSFileManager defaultManager];
  NSError *error;
  BOOL success = [fs createDirectoryAtPath:supportDirectory withIntermediateDirectories:YES attributes:nil error:&error];
  if (!success) {
    NSLog(@"Can't create support directory '%@' because %@", supportDirectory, [error localizedDescription]);
    supportDirectory = @"";
  }

  return supportDirectory;
}
  
+ (CefSettings)createCefSettings {
  CefSettings settings;

  CefString(&settings.cache_path) = [[self supportDirectory] UTF8String];
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

# pragma mark NSApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  _backgroundWindowController = [[AtomWindowController alloc] initInBackground];
#ifdef RESOURCE_PATH
  [self open:[NSString stringWithUTF8String:RESOURCE_PATH]];
#else
  [self open:nil];
#endif
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

