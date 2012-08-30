#import "include/cef_application_mac.h"
#import "native/atom_application.h"

int main(int argc, char* argv[]) {
  @autoreleasepool {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    AtomApplication *application = (AtomApplication *)[AtomApplication sharedApplication];

    NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
    NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
    [mainNib instantiateNibWithOwner:application topLevelObjects:nil];

    CefRunMessageLoop();
  }

  return 0;
}
