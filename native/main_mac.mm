#import "include/cef_application_mac.h"
#import "native/atom_application.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

int main(int argc, char* argv[]) {
  @autoreleasepool {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un addr = { 0, AF_UNIX };
    NSString *socketPath = [NSString stringWithFormat:@"/tmp/atom-%d.sock", getuid()];
    strcpy(addr.sun_path, [socketPath UTF8String]);
    addr.sun_len = SUN_LEN(&addr);
    
    for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
      if ([[app bundleIdentifier] isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]) {
        NSLog(@"%@", @"Well fuck dude, there are two apps open, better send the other one a message!");
        
        struct sockaddr to_addr;
        to_addr.sa_family = AF_UNIX;
        strcpy(to_addr.sa_data, [socketPath UTF8String]);

        char buf[] = "WE JUMPED THE PROCESS";
        if (sendto(fd, buf, sizeof(buf), 0, &to_addr, sizeof(to_addr)) < 0) {
          NSLog(@"Send failure");
          exit(1);
        }
        exit(0);
      }
    }
    
    if (connect(fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
      NSLog(@"EVERYTHING FUCKED UP");
    }
    else {
      NSLog(@"I AM LISTENING");
      
      dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
      dispatch_async(queue, ^{
        char buf[1000];
        struct sockaddr from_addr;
        from_addr.sa_family = AF_UNIX;
        strcpy(from_addr.sa_data, [socketPath UTF8String]);

        if (recvfrom(fd, &buf, sizeof(buf), 0, &from_addr, sizeof(from_addr)) < 0) {
          NSLog(@"NO GOOD, RECEIVE FAILURE");
        }
        else {
          NSLog(@"GOOD! Got %s", buf);
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
