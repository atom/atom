#import "AtomApp.h"
#import "AtomController.h"
#import "JSCocoa.h"

#import <WebKit/WebKit.h>

@implementation AtomApp

@synthesize controllers;

- (AtomController *)createController:(NSString *)path {
  AtomController *controller = [[AtomController alloc] initWithPath:path];
  [controllers addObject:controller];
  return controller;
}

- (void)removeController:(AtomController *)controller {
  [controllers removeObject:controller];
}

// Overridden
- (void)sendEvent:(NSEvent *)event {
  if ([event type] == NSKeyDown) {
    BOOL handeled = NO;
    id controller = [[self keyWindow] windowController];
    
    // The keyWindow could be a Cocoa Dialog or something, ignore that.
    if ([controller isKindOfClass:[AtomController class]]) {
      handeled = [controller handleKeyEvent:event];
    }
    
    if (!handeled) [super sendEvent:event];
  }
  else {
    [super sendEvent:event];
  }
}

// AppDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"WebKitDeveloperExtras", nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  AtomController *controller = [self createController:NULL];
  [controller window];
}

@end
