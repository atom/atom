#import "AtomApp.h"
#import "AtomWindowController.h"
#import "JSCocoa.h"

@implementation AtomApp

- (void)sendEvent:(NSEvent *)event {
  switch ([event type]) {
    case NSKeyDown:
    case NSFlagsChanged: {
      AtomWindowController *controller = (AtomWindowController *)[[self keyWindow] windowController];
      BOOL handeled = [controller handleKeyEvent:event];
      if (!handeled) {
        [super sendEvent:event];
      }
    }
    default:
      [super sendEvent:event];
      break;
  }
}

// AppDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], @"WebKitDeveloperExtras",
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  id c = [[AtomWindowController alloc] initWithWindowNibName:@"AtomWindow"];
  [c window];
}


@end
