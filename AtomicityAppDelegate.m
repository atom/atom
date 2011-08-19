//
//  AtomicityAppDelegate.m
//  Atomicity
//
//  Created by Chris Wanstrath on 8/18/11.
//  Copyright 2011 GitHub. All rights reserved.
//

#import "AtomicityAppDelegate.h"
#import "JSCocoa.h"

@implementation AtomicityAppDelegate

@synthesize window, webView;

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], @"WebKitDeveloperExtras",
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  id path = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
  id html = [[NSString alloc] initWithContentsOfURL:path];
  
  [[webView mainFrame] loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];  
  
  // https://github.com/parmanoir/jscocoa#readme
  JSCocoa* jsc = [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
}

@end
