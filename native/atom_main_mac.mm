#import "atom_main.h"
#import "atom_cef_app.h"
#import "include/cef_application_mac.h"
#import "native/atom_application.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

void sendPathToMainProcessAndExit(int fd, NSString *socketPath, NSDictionary *arguments);
void handleBeingOpenedAgain(int argc, char* argv[]);
void listenForPathToOpen(int fd, NSString *socketPath);
void activateOpenApp();
BOOL isAppAlreadyOpen();

int AtomMain(int argc, char* argv[]) {
  // Check if we're being run as a secondary process.
  CefMainArgs main_args(argc, argv);
  CefRefPtr<CefApp> app(new AtomCefApp);
  int exitCode = CefExecuteProcess(main_args, app);
  if (exitCode >= 0)
    return exitCode;

  // We're the main process.
  @autoreleasepool {
    handleBeingOpenedAgain(argc, argv);

    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    AtomApplication *application = [AtomApplication applicationWithArguments:argv count:argc];

    NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
    NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle bundleWithIdentifier:@"com.github.atom.framework"]];
    [mainNib instantiateWithOwner:application topLevelObjects:nil];

    CefRunMessageLoop();
    CefShutdown();
  }

  return 0;
}

void handleBeingOpenedAgain(int argc, char* argv[]) {
  NSString *socketPath = [NSString stringWithFormat:@"/tmp/atom-%d.sock", getuid()];

  int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  fcntl(fd, F_SETFD, FD_CLOEXEC);

  if (isAppAlreadyOpen()) {
    NSDictionary *arguments = [AtomApplication parseArguments:argv count:argc];
    sendPathToMainProcessAndExit(fd, socketPath, arguments);
  }
  else {
    listenForPathToOpen(fd, socketPath);
  }
}

void sendPathToMainProcessAndExit(int fd, NSString *socketPath, NSDictionary *arguments) {
  struct sockaddr_un send_addr;
  send_addr.sun_family = AF_UNIX;
  strcpy(send_addr.sun_path, [socketPath UTF8String]);

  NSString *path = [arguments objectForKey:@"path"];
  if (path) {
    NSMutableString *packedString = [NSMutableString stringWithString:path];
    if ([arguments objectForKey:@"wait"]) {
      [packedString appendFormat:@"\n%@", [arguments objectForKey:@"pid"]];
    }

    const char *buf = [packedString UTF8String];
    if (sendto(fd, buf, [packedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, (sockaddr *)&send_addr, sizeof(send_addr)) < 0) {
      perror("Error: Failed to sending path to main Atom process");
      exit(1);
    }
  } else {
    activateOpenApp();
  }
  exit(0);
}

void listenForPathToOpen(int fd, NSString *socketPath) {
  struct sockaddr_un addr;
  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path, [socketPath UTF8String]);

  unlink([socketPath UTF8String]);
  if (bind(fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
    perror("ERROR: Binding to socket");
  }
  else {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
      char buf[MAXPATHLEN + 16]; // Add 16 to hold the pid string
      struct sockaddr_un listen_addr;
      listen_addr.sun_family = AF_UNIX;
      strcpy(listen_addr.sun_path, [socketPath UTF8String]);
      socklen_t listen_addr_length;

      while(true) {
        memset(buf, 0, sizeof(buf));
        if (recvfrom(fd, &buf, sizeof(buf), 0, (sockaddr *)&listen_addr, &listen_addr_length) < 0) {
          perror("ERROR: Receiving from socket");
        }
        else {
          NSArray *components = [[NSString stringWithUTF8String:buf] componentsSeparatedByString:@"\n"];
          NSString *path = [components objectAtIndex:0];
          NSNumber *pid = nil;
          if (components.count > 1) pid = [NSNumber numberWithInt:[[components objectAtIndex:1] intValue]];
          dispatch_queue_t mainQueue = dispatch_get_main_queue();
          dispatch_async(mainQueue, ^{
            [[AtomApplication sharedApplication] open:path pidToKillWhenWindowCloses:pid];
            [NSApp activateIgnoringOtherApps:YES];
          });
        }
      }
    });
  }
}

void activateOpenApp() {
  for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
    BOOL hasSameBundleId = [app.bundleIdentifier isEqualToString:[[NSBundle mainBundle] bundleIdentifier]];
    BOOL hasSameProcessesId = app.processIdentifier == [[NSProcessInfo processInfo] processIdentifier];
    if (hasSameBundleId && !hasSameProcessesId) {
      [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
      return;
    }
  }
}

BOOL isAppAlreadyOpen() {
  for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
    BOOL hasSameBundleId = [app.bundleIdentifier isEqualToString:[[NSBundle mainBundle] bundleIdentifier]];
    BOOL hasSameProcessesId = app.processIdentifier == [[NSProcessInfo processInfo] processIdentifier];
    if (hasSameBundleId && !hasSameProcessesId) {
      return true;
    }
  }

  return false;
}
