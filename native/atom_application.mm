#import "include/cef_application_mac.h"
#import "native/atom_cef_client.h"
#import "native/atom_application.h"
#import "native/atom_window_controller.h"
#import "native/atom_cef_app.h"
#import <getopt.h>

@implementation AtomApplication

@synthesize arguments=_arguments;

+ (id)applicationWithArguments:(char **)argv count:(int)argc {
  AtomApplication *application = (AtomApplication *)[super sharedApplication];
  CefInitialize(CefMainArgs(argc, argv), [self createCefSettings], new AtomCefApp);
  [application parseArguments:argv count:argc];  
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
  [_arguments release];
  [super dealloc];
}

- (void)open:(NSString *)path {
  [[AtomWindowController alloc] initWithPath:path];
}

- (IBAction)runSpecs:(id)sender {
  [self runSpecsThenExit:NO];
}

- (void)runSpecsThenExit:(BOOL)exitWhenDone {
  [[AtomWindowController alloc] initSpecsThenExit:exitWhenDone];
}

- (IBAction)runBenchmarks:(id)sender {
  [self runBenchmarksThenExit:NO];
}

- (void)runBenchmarksThenExit:(BOOL)exitWhenDone {
  [[AtomWindowController alloc] initBenchmarksThenExit:exitWhenDone];
}

- (void)parseArguments:(char **)argv count:(int)argc {
  _arguments = [[NSMutableDictionary alloc] init];
  
  // Defaults
  #ifdef RESOURCE_PATH
    [_arguments setObject:[NSString stringWithUTF8String:RESOURCE_PATH] forKey:@"resource-path"];
  #endif

  
  int opt;
  int longindex;
  
  if (argc > 2 && strcmp(argv[argc - 2], "-NSDocumentRevisionsDebugMode") == 0) { // Because Xcode inserts useless command-line args by default: http://trac.wxwidgets.org/ticket/13732
    argc -= 2; // Ignore last two arguments
  }
  
  static struct option longopts[] = {
    { "resource-path",      optional_argument,      NULL,  'r' },
    { "benchmark",          optional_argument,      NULL,  'b' },
    { "test",               optional_argument,      NULL,  't' },
    { NULL,                 0,                      NULL,  0 }
  };
  
  while ((opt = getopt_long(argc, argv, "r:bth?", longopts, &longindex)) != -1) {
    switch (opt) {
      case 'r':
        [_arguments setObject:[NSString stringWithUTF8String:optarg] forKey:@"resource-path"];
        break;
      case 'b':
        [_arguments setObject:[NSNumber numberWithBool:YES] forKey:@"benchmark"];
        break;
      case 't':
        [_arguments setObject:[NSNumber numberWithBool:YES] forKey:@"test"];
        break;
      default:
        printf("usage: atom [--resource-path=<path>] [<path>]");
    }
  }
  
  argc -= optind;
  argv += optind;
  
  if (argc > 0) {
    [_arguments setObject:[NSString stringWithUTF8String:argv[0]] forKey:@"path"];
  }
}

# pragma mark NSApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  _backgroundWindowController = [[AtomWindowController alloc] initInBackground];
    
  if ([_arguments objectForKey:@"benchmark"]) {
    [self runBenchmarksThenExit:true];
  }
  else if ([_arguments objectForKey:@"test"]) {
    [self runSpecsThenExit:true];
  }
  else {
    NSLog(@"%@", [_arguments objectForKey:@"path"]);
    [self open:@"/Users/corey/atom"];//[_arguments objectForKey:@"path"]];
  }
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

