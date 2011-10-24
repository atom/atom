//
//  AtomWindowController.m
//  Atomicity
//
//  Created by Chris Wanstrath on 8/22/11.
//  Copyright 2011 GitHub. All rights reserved.
//`

#import "AtomController.h"
#import "AtomApp.h"

#import <WebKit/WebKit.h>
#import "JSCocoa.h"

@implementation AtomController

@synthesize webView, URL;

- (void)dealloc {
  [jscocoa unlinkAllReferences];
  [jscocoa garbageCollect];
  [jscocoa release]; jscocoa = nil;
  
  [webView release];
  [URL release];
  
  [super dealloc];
}

- (id)initWithURL:(NSString *)_URL {
  self = [super initWithWindowNibName:@"AtomWindow"];
  self.URL = _URL;
  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];

  [webView setUIDelegate:self];
  
  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomController"];

  if (self.URL) {
    [webView setMainFrameURL:self.URL];
  }
  else {
    jscocoa = [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
    [jscocoa setObject:self withName:@"atomController"];

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *requirePath = [resourcePath stringByAppendingString:@"/src/require.js"];
    [jscocoa evalJSFile:requirePath];

    NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL *indexURL = [resourceURL URLByAppendingPathComponent:@"index.html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:indexURL]; 
    [[webView mainFrame] loadRequest:request];
  }
}

- (void)close {
  [(AtomApp *)NSApp removeController:self];
  [super close];
}

- (BOOL)handleKeyEvent:(NSEvent *)event {
  // ICKY: Using a global function defined in App.js to deal with key events
  JSValueRef returnValue = [jscocoa callJSFunctionNamed:@"handleKeyEvent" withArguments:event, nil];
  return [jscocoa toBool:returnValue];
}

// WebUIDelegate Protocol
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
  return [NSArray array];   
}


@end
