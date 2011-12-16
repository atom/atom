#import "AtomApp.h"
#import "AtomController.h"
#import "JSCocoa.h"

#import <WebKit/WebKit.h>

#define ATOM_USER_PATH ([[NSString stringWithString:@"~/.atom/"] stringByStandardizingPath])
#define ATOM_STORAGE_PATH ([ATOM_USER_PATH stringByAppendingPathComponent:@".app-storage"])

@implementation AtomApp

@synthesize controllers = _controllers;

- (void)open:(NSString *)path {
  AtomController *controller = [[AtomController alloc] initWithURL:path];
  [self.controllers addObject:controller];
}

- (AtomController *)createSpecController {
  AtomController *controller = [[AtomController alloc] initForSpecs];
  return controller;
}

- (void)removeController:(AtomController *)controller {
  [self.controllers removeObject:controller];
}

// Events in the "app:*" namespace are sent to all controllers
- (void)triggerGlobalAtomEvent:(NSString *)name data:(id)data {
  for (AtomController *controller in self.controllers) {
    [controller triggerAtomEventWithName:name data:data];
  }
}

#pragma mark Overrides
- (void)sendEvent:(NSEvent *)event {
  if ([event type] != NSKeyUp) {
    [super sendEvent:event];
    return;
  }
  
  BOOL shouldRunSpecs = [event modifierFlags] & (NSAlternateKeyMask | NSControlKeyMask | NSCommandKeyMask) && [[event charactersIgnoringModifiers] hasPrefix:@"s"];
  if (shouldRunSpecs) {
    [self createSpecController];
    return;
  }

  AtomController *controller = [[self keyWindow] windowController];
  if ([controller isKindOfClass:[AtomController class]]) { // ensure its not a dialog
    if ([controller handleInputEvent:event]) return;
  }
  
  [super sendEvent:event];
}

- (void)terminate:(id)sender {
  for (AtomController *controller in self.controllers) {
    [controller close];
  }
  
  [super terminate:sender];
}

#pragma mark NSAppDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
  self.controllers = [NSMutableArray array];
  
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"WebKitDeveloperExtras", nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

@end
