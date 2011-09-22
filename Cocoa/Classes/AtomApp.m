#import "AtomApp.h"
#import "AtomWindowController.h"
#import "JSCocoa.h"

@implementation AtomApp

- (void)sendEvent:(NSEvent *)event {
  switch ([event type]) {
    case NSKeyDown:
    case NSFlagsChanged:
      {
        BOOL handeled = NO;
        id controller = [[self keyWindow] windowController];
        
        // The keyWindow could be a Cocoa Dialog or something, ignore them.
        if ([controller isKindOfClass:[AtomWindowController class]]) {
          handeled = [controller handleKeyEvent:event];
        }

        if (!handeled) {
          [super sendEvent:event];
        }

      }
      break;
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
