#import "AtomApp.h"
#import "AtomController.h"
#import "JSCocoa.h"

#import <WebKit/WebKit.h>

#define ATOM_USER_PATH @"~/.atomicity/"

@implementation AtomApp

@synthesize controllers;

- (AtomController *)createController:(NSString *)path {
  AtomController *controller = [[AtomController alloc] initWithPath:path];
  [controllers addObject:controller];
  [controller.window makeKeyAndOrderFront:self];
  return controller;
}

- (void)removeController:(AtomController *)controller {
  [controllers removeObject:controller];
}

- (void)open:(NSString *)path {
  if (!path) {
    NSOpenPanel *panel =[NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    if (panel.runModal != NSFileHandlingPanelOKButton) return;

    path = [[[panel URLs] lastObject] path];
  }
  
  for (AtomController *controller in controllers) {   
    JSValueRef value = [controller.jscocoa callJSFunctionNamed:@"canOpen" withArguments:path , nil];
    if ([controller.jscocoa toBool:value]) {
      [controller.jscocoa callJSFunctionNamed:@"open" withArguments:path, nil];
      return;
    }
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
  if ([event type] == NSKeyDown) {
    BOOL handeled = NO;
    AtomController *controller = [[self keyWindow] windowController];
    
    // The keyWindow could be a Cocoa Dialog or something, ignore that.
    if ([controller isKindOfClass:[AtomController class]]) {
      JSValueRef value = [controller.jscocoa callJSFunctionNamed:@"handleKeyEvent" withArguments:event, nil];
      handeled = [controller.jscocoa toBool:value];
    }
    
    if (!handeled) [super sendEvent:event];
  }
  else {
    [super sendEvent:event];
  }
}

// AppDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
  self.controllers = [NSMutableArray array];
  
  // Hack to make localStorage work
  WebPreferences* prefs = [WebPreferences standardPreferences];
  [prefs _setLocalStorageDatabasePath:ATOM_USER_PATH @"storage"];
  [prefs setLocalStorageEnabled:YES];

  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"WebKitDeveloperExtras", nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [self createController:NULL];
}

@end
