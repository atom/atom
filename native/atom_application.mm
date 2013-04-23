#import "include/cef_application_mac.h"
#import "native/atom_cef_client.h"
#import "native/atom_application.h"
#import "native/atom_window_controller.h"
#import "native/atom_cef_app.h"
#import <getopt.h>
#import <Sparkle/Sparkle.h>
#import <Quincy/BWQuincyManager.h>

@implementation AtomApplication

@synthesize arguments=_arguments;

+ (AtomApplication *)sharedApplication {
  return (AtomApplication *)[super sharedApplication];
}

+ (id)applicationWithArguments:(char **)argv count:(int)argc {
  AtomApplication *application = [self sharedApplication];
  CefInitialize(CefMainArgs(argc, argv), [self createCefSettings], new AtomCefApp);
  application.arguments = [self parseArguments:argv count:argc];

  return application;
}

+ (NSDictionary *)parseArguments:(char **)argv count:(int)argc {
  NSMutableDictionary *arguments = [[NSMutableDictionary alloc] init];

  // Remove non-posix (i.e. -long_argument_with_one_leading_hyphen) added by OS X from the command line
  int cleanArgc = argc;
  size_t argvSize = argc * sizeof(char *);
  char **cleanArgv = (char **)alloca(argvSize);
  for (int i=0; i < argc; i++) {
    if (strcmp(argv[i], "-NSDocumentRevisionsDebugMode") == 0) { // Xcode inserts useless command-line args by default: http://trac.wxwidgets.org/ticket/13732
      cleanArgc -= 2;
      i++;
    }
    else if (strncmp(argv[i], "-psn_", 5) == 0) { // OS X inserts a -psn_[PID] argument.
      cleanArgc -= 1;
    }
    else {
      cleanArgv[i] = argv[i];
    }
  }

  int opt;
  int longindex;

  static struct option longopts[] = {
    { "executed-from",      required_argument,      NULL,  'K'  },
    { "resource-path",      required_argument,      NULL,  'R'  },
    { "benchmark",          no_argument,            NULL,  'B'  },
    { "test",               no_argument,            NULL,  'T'  },
    { "dev",                no_argument,            NULL,  'D'  },
    { "pid",                required_argument,      NULL,  'P'  },
    { "wait",               no_argument,            NULL,  'W'  },
    { NULL,                 0,                      NULL,  0 }
  };

  while ((opt = getopt_long(cleanArgc, cleanArgv, "K:R:BYDP:Wh?", longopts, &longindex)) != -1) {
    NSString *key, *value;
    switch (opt) {
      case 'K':
      case 'R':
      case 'B':
      case 'T':
      case 'D':
      case 'W':
      case 'P':
        key = [NSString stringWithUTF8String:longopts[longindex].name];
        value = optarg ? [NSString stringWithUTF8String:optarg] : @"YES";
        [arguments setObject:value forKey:key];
        break;
      case 0:
        break;
      default:
        NSLog(@"usage: atom [--resource-path=<path>] [<path>]");
    }
  }

  cleanArgc -= optind;
  cleanArgv += optind;

  if (cleanArgc > 0) {
    NSString *path = [NSString stringWithUTF8String:cleanArgv[0]];
    path = [self standardizePathToOpen:path withArguments:arguments];
    [arguments setObject:path forKey:@"path"];
  } else {
    NSString *executedFromPath = [arguments objectForKey:@"executed-from"];
    if (executedFromPath) {
      [arguments setObject:executedFromPath forKey:@"path"];
    }
  }

  return arguments;
}

+ (NSString *)standardizePathToOpen:(NSString *)path withArguments:(NSDictionary *)arguments {
  NSString *standardizedPath = path;
  NSString *executedFromPath = [arguments objectForKey:@"executed-from"];
  if (![standardizedPath isAbsolutePath] && executedFromPath) {
    standardizedPath = [executedFromPath stringByAppendingPathComponent:standardizedPath];
  }
  standardizedPath = [standardizedPath stringByStandardizingPath];
  return standardizedPath;
}

+ (NSString *)supportDirectory {
  NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  NSString *executableName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
  NSString *supportDirectory = [cachePath stringByAppendingPathComponent:executableName];

  NSFileManager *fs = [NSFileManager defaultManager];
  NSError *error;
  BOOL success = [fs createDirectoryAtPath:supportDirectory withIntermediateDirectories:YES attributes:nil error:&error];
  if (!success) {
    NSLog(@"Warning: Can't create support directory '%@' because %@", supportDirectory, [error localizedDescription]);
    supportDirectory = @"";
  }

  return supportDirectory;
}

+ (CefSettings)createCefSettings {
  CefSettings settings;

  NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
  NSString *userAgent = [NSString stringWithFormat:@"GitHubAtom/%@", version];
  CefString(&settings.cache_path) = [[self supportDirectory] UTF8String];
  CefString(&settings.user_agent) = [userAgent UTF8String];
  CefString(&settings.log_file) = "";
  CefString(&settings.javascript_flags) = "--harmony_collections";
  settings.remote_debugging_port = 9090;
  settings.log_severity = LOGSEVERITY_ERROR;
  return settings;
}

- (void)dealloc {
  [_backgroundWindowController release];
  [_arguments release];
  [_updateInvocation release];
  [super dealloc];
}

- (void)open:(NSString *)path pidToKillWhenWindowCloses:(NSNumber *)pid {
  BOOL openingDirectory = false;
  [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&openingDirectory];

  if (!pid) {
    for (NSWindow *window in [self windows]) {
      if (![window isExcludedFromWindowsMenu]) {
        AtomWindowController *controller = [window windowController];
        if (!controller.pathToOpen) {
          continue;
        }
        if (!openingDirectory) {
          BOOL openedPathIsDirectory = false;
          [[NSFileManager defaultManager] fileExistsAtPath:controller.pathToOpen isDirectory:&openedPathIsDirectory];
          NSString *projectPath = NULL;
          if (openedPathIsDirectory) {
            projectPath = [NSString stringWithFormat:@"%@/", controller.pathToOpen];
          }
          else {
            projectPath = [controller.pathToOpen stringByDeletingLastPathComponent];
          }
          if ([path hasPrefix:projectPath]) {
            [window makeKeyAndOrderFront:nil];
            [controller openPath:path];
            return;
          }
        }

        if ([path isEqualToString:controller.pathToOpen]) {
          [window makeKeyAndOrderFront:nil];
          return;
        }
      }
    }
  }

  AtomWindowController *windowController = [[AtomWindowController alloc] initWithPath:path];
  [windowController setPidToKillOnClose:pid];
  return windowController;
}

- (void)open:(NSString *)path {
  [self open:path pidToKillWhenWindowCloses:nil];
}

- (void)openDev:(NSString *)path {
  [[AtomWindowController alloc] initDevWithPath:path];
}

- (void)openConfig {
  for (NSWindow *window in [self windows]) {
    if ([[window windowController] isConfig]) {
      [window makeKeyAndOrderFront:nil];
      return;
    }
  }
  [[AtomWindowController alloc] initConfig];
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

# pragma mark NSApplicationDelegate

- (BOOL)shouldOpenFiles {
  if ([self.arguments objectForKey:@"benchmark"]) {
    return NO;
  }
  if ([self.arguments objectForKey:@"test"]) {
    return NO;
  }
  return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
  if ([self shouldOpenFiles]) {
    for (NSString *path in filenames) {
      path = [[self class] standardizePathToOpen:path withArguments:self.arguments];
      NSNumber *pid = [self.arguments objectForKey:@"wait"] ? [self.arguments objectForKey:@"pid"] : nil;
      [self open:path pidToKillWhenWindowCloses:pid];
    }
    if ([filenames count] > 0) {
      _filesOpened = YES;
    }
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  BWQuincyManager *manager = [BWQuincyManager sharedQuincyManager];
  [manager setCompanyName:@"GitHub"];
  [manager setSubmissionURL:@"https://speakeasy.githubapp.com/submit_crash_log"];
  [manager setAutoSubmitCrashReport:YES];

  if (!_filesOpened && [self shouldOpenFiles]) {
    NSString *path = [self.arguments objectForKey:@"path"];
    NSNumber *pid = [self.arguments objectForKey:@"wait"] ? [self.arguments objectForKey:@"pid"] : nil;
    [self open:path pidToKillWhenWindowCloses:pid];
  }
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
  _versionMenuItem.title = [NSString stringWithFormat:@"Version %@", version];

  if ([self.arguments objectForKey:@"benchmark"]) {
    [self runBenchmarksThenExit:true];
  }
  else if ([self.arguments objectForKey:@"test"]) {
    [self runSpecsThenExit:true];
  }
  else {
    _backgroundWindowController = [[AtomWindowController alloc] initInBackground];

#if defined(CODE_SIGNING_ENABLED)
    SUUpdater.sharedUpdater.delegate = self;
    SUUpdater.sharedUpdater.automaticallyChecksForUpdates = YES;
    SUUpdater.sharedUpdater.automaticallyDownloadsUpdates = YES;
    [SUUpdater.sharedUpdater checkForUpdatesInBackground];
#endif

  }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:
      (NSApplication *)sender {
  for (NSWindow *window in [self windows]) {
    [window performClose:self];
  }

  return NSTerminateCancel;
}

# pragma mark CefAppProtocol

- (BOOL)isHandlingSendEvent {
  return _handlingSendEvent;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  _handlingSendEvent = handlingSendEvent;
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

#pragma mark SUUpdaterDelegate

- (void)updaterDidNotFindUpdate:(SUUpdater *)update {
}

- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update {
}

- (void)updater:(SUUpdater *)updater willExtractUpdate:(SUAppcastItem *)update {
}

- (void)updater:(SUUpdater *)updater willInstallUpdateOnQuit:(SUAppcastItem *)update immediateInstallationInvocation:(NSInvocation *)invocation {
  _updateInvocation = [invocation retain];
  _versionMenuItem.title = [NSString stringWithFormat:@"Update to %@", update.versionString];
  _versionMenuItem.target = _updateInvocation;
  _versionMenuItem.action = @selector(invoke);
}

- (void)updater:(SUUpdater *)updater didCancelInstallUpdateOnQuit:(SUAppcastItem *)update {
}

@end
