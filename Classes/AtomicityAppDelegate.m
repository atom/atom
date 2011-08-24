//
//  AtomicityAppDelegate.m
//  Atomicity
//
//  Created by Chris Wanstrath on 8/18/11.
//  Copyright 2011 GitHub. All rights reserved.
//

#import "AtomicityAppDelegate.h"
#import "AtomWindowController.h"

@implementation AtomicityAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], @"WebKitDeveloperExtras",
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  AtomWindowController* ctrl = [[AtomWindowController alloc] initWithWindowNibName:@"AtomWindow"];
  [ctrl window];
}

@end
