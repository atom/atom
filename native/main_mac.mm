#import "include/cef_application_mac.h"
#import "native/atom_application.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

int main(int argc, char* argv[]) {
  @autoreleasepool {
    NSString *socketPath = [NSString stringWithFormat:@"/tmp/atom-%d.sock", getuid()];

    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    
    for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
      BOOL hasSameBundleId = [app.bundleIdentifier isEqualToString:[[NSBundle mainBundle] bundleIdentifier]];
      BOOL hasSameProcessesId = app.processIdentifier == [[NSProcessInfo processInfo] processIdentifier];
      if (hasSameBundleId && !hasSameProcessesId) {
        struct sockaddr_un send_addr;
        send_addr.sun_family = AF_UNIX;
        strcpy(send_addr.sun_path, [socketPath UTF8String]);

        char buf[] = "WE JUMPED THE PROCESS";
        if (sendto(fd, buf, sizeof(buf), 0, (sockaddr *)&send_addr, sizeof(send_addr)) < 0) {
          NSLog(@"Send failure");
          exit(1);
        }
        exit(0);
      }
    }
    
    struct sockaddr_un addr;
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, [socketPath UTF8String]);
    
    unlink([socketPath UTF8String]);
    if (bind(fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
      perror("ERROR: Binding to socket");
    }
    else {
      NSLog(@"I AM LISTENING");
      
      dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
      dispatch_async(queue, ^{
        char buf[1000];
        struct sockaddr_un listen_addr;
        listen_addr.sun_family = AF_UNIX;
        strcpy(listen_addr.sun_path, [socketPath UTF8String]);
        socklen_t listen_addr_length;
        if (recvfrom(fd, &buf, sizeof(buf), 0, (sockaddr *)&listen_addr, &listen_addr_length) < 0) {
          perror("ERROR: Receiving from socket");
        }
        else {
          NSLog(@"GOOD! Got %s from %s", buf, listen_addr.sun_path);
        }
      });
    }
    
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    AtomApplication *application = [AtomApplication applicationWithArguments:argv count:argc];

    NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
    NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
    [mainNib instantiateNibWithOwner:application topLevelObjects:nil];
    
    CefRunMessageLoop();
    close(fd);
  }

  return 0;
}
