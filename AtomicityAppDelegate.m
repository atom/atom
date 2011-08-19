//
//  AtomicityAppDelegate.m
//  Atomicity
//
//  Created by Chris Wanstrath on 8/18/11.
//  Copyright 2011 GitHub. All rights reserved.
//

#import "AtomicityAppDelegate.h"

@implementation AtomicityAppDelegate

@synthesize window, webView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], @"WebKitDeveloperExtras",
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  
  id path = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
  id html = [[NSString alloc] initWithContentsOfURL:path];
  
  [[webView mainFrame] loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];  
}

@end
