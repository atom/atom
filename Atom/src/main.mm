#import <Cocoa/Cocoa.h>

#include "include/cef_base.h"
#include "include/cef_app.h"

int main(int argc, char* argv[]) {
  @autoreleasepool {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    Class principalClass = NSClassFromString([infoDictionary objectForKey:@"NSPrincipalClass"]);
    NSApplication *application = [principalClass sharedApplication];
    
    NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
    NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
    [mainNib instantiateNibWithOwner:application topLevelObjects:nil];
      
    // Run the application message loop.
    CefRunMessageLoop();
    
    // Don't put anything below this line because it won't be executed.
    return 0;
  }
}
