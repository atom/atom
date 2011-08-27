//
//  AtomicityAppDelegate.m
//  Atomicity
//
//  Created by Chris Wanstrath on 8/18/11.
//  Copyright 2011 GitHub. All rights reserved.
//

#import "AtomicityAppDelegate.h"
#import "AtomWindowController.h"
#import "JSCocoa.h"

@implementation AtomicityAppDelegate

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
