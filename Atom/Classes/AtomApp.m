#import "AtomApp.h"
#import "AtomController.h"
#import "JSCocoa.h"

#import <WebKit/WebKit.h>

#define ATOM_USER_PATH ([[NSString stringWithString:@"~/.atom/"] stringByStandardizingPath])
#define ATOM_STORAGE_PATH ([ATOM_USER_PATH stringByAppendingPathComponent:@".app-storage"])

@implementation AtomApp

@synthesize controllers;

- (AtomController *)createController:(NSString *)path {
  AtomController *controller = [(AtomController *)[AtomController alloc] initWithURL:path];
  [controllers addObject:controller];
  
  return controller;
}

- (void)removeController:(AtomController *)controller {
  [controllers removeObject:controller];
  [controller.jscocoa callJSFunctionNamed:@"triggerEvent" withArguments:@"window:close", nil, false, nil];
}

- (void)runSpecs {
  AtomController *controller = [(AtomController *)[AtomController alloc] initForSpecs];
  [controllers addObject:controller];
}

- (void)reloadController:(AtomController *)controller {
  CGRect frame = [[controller window] frame];
  AtomController *newController = [self createController:controller.url];
  [controller close];
  [[newController window] setFrame:frame display:YES animate:NO];
}

- (void)open:(NSString *)path {
  if (!path) {
    NSOpenPanel *panel =[NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    if (panel.runModal != NSFileHandlingPanelOKButton) return;

    path = [[[panel URLs] lastObject] path];
  }

  [self createController:path];
}

// Events in the "app:*" namespace get sent to all controllers
- (void)triggerGlobalEvent:(NSString *)name data:(id)data {
  for (AtomController *controller in controllers) {
    [controller.jscocoa callJSFunctionNamed:@"triggerEvent" withArguments:name, data, false, nil];
  }
}

// Overridden
- (void)sendEvent:(NSEvent *)event {
  if ([event type] != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

  BOOL handeled = NO;
  AtomController *controller = [[self keyWindow] windowController];

  // The keyWindow could be a Cocoa Dialog or something, ignore those.
  if ([controller isKindOfClass:[AtomController class]]) {
    // cmd-r should always reload the current controller, so it needs to be here
    if ([event modifierFlags] & NSCommandKeyMask && [[event charactersIgnoringModifiers] hasPrefix:@"r"]) {
      [self reloadController:controller];
      handeled = YES;
    }
    else if ([event modifierFlags] & (NSAlternateKeyMask | NSControlKeyMask | NSCommandKeyMask) && [[event charactersIgnoringModifiers] hasPrefix:@"s"]) {
      [self runSpecs];
      handeled = YES;
    }
    else {
      JSValueRef value = [controller.jscocoa callJSFunctionNamed:@"handleKeyEvent" withArguments:event, nil];
      handeled = [controller.jscocoa toBool:value];
    }
  }
  
  if (!handeled) [super sendEvent:event];
}

- (void)terminate:(id)sender {
  for (AtomController *controller in controllers) {   
    [controller.jscocoa callJSFunctionNamed:@"shutdown" withArguments:nil];
  }
  
  [super terminate:sender];
}

// AppDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
  self.controllers = [NSMutableArray array];
  
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"WebKitDeveloperExtras", nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [self createController:nil];
}

@end
