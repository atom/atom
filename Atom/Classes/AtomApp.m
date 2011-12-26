#import "AtomApp.h"

#import "JSCocoa.h"
#import <WebKit/WebKit.h>

#import "AtomController.h"
#import "AtomMenuItem.h"

#define ATOM_USER_PATH ([[NSString stringWithString:@"~/.atom/"] stringByStandardizingPath])
#define ATOM_STORAGE_PATH ([ATOM_USER_PATH stringByAppendingPathComponent:@".app-storage"])

@implementation AtomApp

@synthesize controllers = _controllers;

- (void)open:(NSString *)path {
  AtomController *controller = [[AtomController alloc] initWithURL:path];
  [self.controllers addObject:controller];
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
- (void) sendEvent: (NSEvent *)event {    
  // Default implementation for key down tries key equivalents first
  // We want to wait until the web view handles the event, then allow key equivalents to be tried
  if (([event type] != NSKeyDown) || !event.window) {
    [super sendEvent:event];
    return;
  }
      
  [event.window sendEvent:event];
}

#pragma mark Actions
- (IBAction)openNewWindow:(id)sender {
  [self open:nil];
}

- (IBAction)openFileInNewWindow:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:NO];
  if ([panel runModal] == NSFileHandlingPanelOKButton) {
    [self open:[panel.URLs.lastObject path]];
  }
}

- (IBAction)runSpecs:(id)sender {
  [[AtomController alloc] initForSpecs];
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

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  if ([[[NSProcessInfo  processInfo] environment] objectForKey:@"AUTO-TEST"]) {
    [self runSpecs:self];
  }
}

- (void)performActionForMenuItem:(AtomMenuItem *)item {
  AtomController *atomController = self.keyWindow.windowController;
  [atomController performActionForMenuItemPath:item.itemPath];
}

- (void)resetMenu:(NSMenu *)menu {
  for (AtomMenuItem *item in menu.itemArray) {
    if (![item isKindOfClass:[AtomMenuItem class]]) continue;

    if (item.submenu) {
      [self resetMenu:item.submenu];
      if (item.submenu.numberOfItems == 0) {
        [menu removeItem:item];
      }
    }
    else if (!item.global) {
      [menu removeItem:item];
    }
  }
}

- (void)resetMainMenu {
  [self resetMenu:self.mainMenu];
}

@end
