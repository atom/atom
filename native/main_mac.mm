#import "include/cef_application_mac.h"
#import "native/atom_application.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

void sendPathToMainProcessAndExit(int fd, NSString *socketPath, NSString *path);
void handleBeingOpenedAgain(int argc, char* argv[]);
void listenForPathToOpen(int fd, NSString *socketPath);
BOOL isAppAlreadyOpen();

int main(int argc, char* argv[]) {
  @autoreleasepool {
    handleBeingOpenedAgain(argc, argv);

    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    AtomApplication *application = [AtomApplication applicationWithArguments:argv count:argc];

    NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
    NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
    [mainNib instantiateNibWithOwner:application topLevelObjects:nil];

    CefRunMessageLoop();
  }

  return 0;
}

void handleBeingOpenedAgain(int argc, char* argv[]) {
  NSString *socketPath = [NSString stringWithFormat:@"/tmp/atom-%d.sock", getuid()];

  int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  fcntl(fd, F_SETFD, FD_CLOEXEC);

  if (isAppAlreadyOpen()) {
    sendPathToMainProcessAndExit(fd, socketPath, [[AtomApplication parseArguments:argv count:argc] objectForKey:@"path"]);
  }
  else {
    listenForPathToOpen(fd, socketPath);
  }
}

void sendPathToMainProcessAndExit(int fd, NSString *socketPath, NSString *path) {
  struct sockaddr_un send_addr;
  send_addr.sun_family = AF_UNIX;
  strcpy(send_addr.sun_path, [socketPath UTF8String]);

  if (path) {
    const char *buf = [path UTF8String];
    if (sendto(fd, buf, [path lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, (sockaddr *)&send_addr, sizeof(send_addr)) < 0) {
      perror("Error: Failed to send path to main Atom process");
      exit(1);
    }
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
      char buf[MAXPATHLEN];
      struct sockaddr_un listen_addr;
      listen_addr.sun_family = AF_UNIX;
      strcpy(listen_addr.sun_path, [socketPath UTF8String]);
      socklen_t listen_addr_length;

      while(true) {
        memset(buf, 0, MAXPATHLEN);
        if (recvfrom(fd, &buf, sizeof(buf), 0, (sockaddr *)&listen_addr, &listen_addr_length) < 0) {
          perror("ERROR: Receiving from socket");
        }
        else {
          NSString *path = [NSString stringWithUTF8String:buf];
          dispatch_queue_t mainQueue = dispatch_get_main_queue();
          dispatch_async(mainQueue, ^{
            [[AtomApplication sharedApplication] open:path];
            [NSApp activateIgnoringOtherApps:YES];
          });
        }
      }
    });
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
