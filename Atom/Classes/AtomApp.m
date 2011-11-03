#import "AtomApp.h"
#import "AtomController.h"
#import "JSCocoa.h"

#import <WebKit/WebKit.h>

#define ATOM_USER_PATH ([[NSString stringWithString:@"~/.atomicity/"] stringByStandardizingPath])
#define ATOM_STORAGE_PATH ([ATOM_USER_PATH stringByAppendingPathComponent:@".app-storage"])
#define WEB_STORAGE_PATH ([ATOM_USER_PATH stringByAppendingPathComponent:@".web-storage"])

@implementation AtomApp

@synthesize controllers;

- (AtomController *)createController:(NSString *)path {
  // Don't like this storage code in here.
  if (path) {
    NSMutableArray *storage = [NSMutableArray arrayWithContentsOfFile:ATOM_STORAGE_PATH];
    if (!storage) storage = [NSMutableArray array];
    if (![storage containsObject:path]) {
      [storage addObject:path];
      [storage writeToFile:ATOM_STORAGE_PATH atomically:YES];
    }
  }
      
  AtomController *controller = [[AtomController alloc] initWithPath:path];
  [controllers addObject:controller];
  [[controller window] makeKeyWindow];
  return controller;
}

- (void)removeController:(AtomController *)controller {
  [controllers removeObject:controller];
  
  NSMutableArray *storage = [NSMutableArray arrayWithContentsOfFile:ATOM_STORAGE_PATH];
  [storage removeObject:controller.path];
  [storage writeToFile:ATOM_STORAGE_PATH atomically:YES];
}

- (void)open:(NSString *)path {
  if (!path) {
    NSOpenPanel *panel =[NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    if (panel.runModal != NSFileHandlingPanelOKButton) return;

    path = [[[panel URLs] lastObject] path];
  }
  
  for (AtomController *controller in controllers) {   
    JSValueRef value = [controller.jscocoa callJSFunctionNamed:@"canOpen" withArguments:path, nil];
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
  [prefs _setLocalStorageDatabasePath:WEB_STORAGE_PATH];
  [prefs setLocalStorageEnabled:YES];

  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], @"WebKitDeveloperExtras", 
                            [NSNumber numberWithBool:YES], @"WebKitScriptDebuggerEnabled",
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  NSError *error = nil;
  BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:ATOM_USER_PATH withIntermediateDirectories:YES attributes:nil error:&error];
  if (!success || error) {
    [NSException raise:@"Atom: Failed to open storage path at '%@'. %@" format:ATOM_USER_PATH, [error localizedDescription]];
  }
  
  // Don't like this storage code in here.
  NSMutableArray *storage = [NSMutableArray arrayWithContentsOfFile:ATOM_STORAGE_PATH];
  if (storage.count == 0) {
    [self createController:NULL];
  }
  else {
    for (NSString *path in storage) {
      [self createController:path];
    }
  }
}

@end
