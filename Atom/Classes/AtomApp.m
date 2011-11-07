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
  if (path) {
    NSMutableArray *openedPaths = [self storageGet:@"app.openedPaths" defaultValue:[NSMutableArray array]];
    if (![openedPaths containsObject:path]) {
      [openedPaths addObject:path];
      [self storageSet:@"app.openedPaths" value:openedPaths];
    }
  }
      
  AtomController *controller = [[AtomController alloc] initWithPath:path];
  [controllers addObject:controller];
  
  // window.coffee will set the window size
  [[controller window] setFrame:NSMakeRect(0, 0, 0, 0) display:YES animate:NO];
  return controller;
}

- (void)removeController:(AtomController *)controller {
  [controllers removeObject:controller];
  
  NSMutableArray *openedPaths = [self storageGet:@"app.openedPaths" defaultValue:[NSMutableArray array]];
  [openedPaths removeObject:controller.path];
  [self storageSet:@"app.openedPaths" value:openedPaths];
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

- (void)terminate:(id)sender {
  for (AtomController *controller in controllers) {   
    [controller.jscocoa callJSFunctionNamed:@"shutdown" withArguments:nil];
  }
  
  [super terminate:sender];
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
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  NSError *error = nil;
  BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:ATOM_USER_PATH withIntermediateDirectories:YES attributes:nil error:&error];
  if (!success || error) {
    [NSException raise:@"Atom: Failed to open storage path at '%@'. %@" format:ATOM_USER_PATH, [error localizedDescription]];
  }
  
  NSArray *openedPaths = [self storageGet:@"app.openedPaths" defaultValue:[NSMutableArray array]];
  if (openedPaths.count == 0) {
    [self createController:NULL];
  }
  else {
    for (NSString *path in openedPaths) {
      [self createController:path];
    }
  }
}

// Helper Methods that should probably go elsewhere
- (id)storage {
  id storage = [NSMutableDictionary dictionaryWithContentsOfFile:ATOM_STORAGE_PATH];
  if (!storage) storage = [NSMutableDictionary dictionary];
  
  return storage;
}

- (id)storageGet:(NSString *)keyPath defaultValue:(id)defaultValue {
  id storage = [NSMutableDictionary dictionaryWithContentsOfFile:ATOM_STORAGE_PATH];
  if (!storage) storage = [NSMutableDictionary dictionary];

  id value = [storage valueForKeyPath:keyPath];
  if (!value) value = defaultValue;
  
  return value;
}

- (id)storageSet:(NSString *)keyPath value:(id)value {
  id storage = [NSMutableDictionary dictionaryWithContentsOfFile:ATOM_STORAGE_PATH];
  if (!storage) storage = [NSMutableDictionary dictionary];

  NSArray *keys = [keyPath componentsSeparatedByString:@"."];
  id parent = storage;
  for (int i = 0; i < keys.count - 1; i++) {
    NSString *key = [keys objectAtIndex:i];
    id newParent = [parent valueForKey:key];
    if (!newParent) {
      newParent = [NSMutableDictionary dictionary];
      [parent setValue:newParent forKey:key];
    }
    parent = newParent;
  }

  [storage setValue:value forKeyPath:keyPath];
  
  [storage writeToFile:ATOM_STORAGE_PATH atomically:YES];
  
  return value;  
}

@end
