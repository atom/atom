//
//  AtomWindowController.m
//  Atomicity
//
//  Created by Chris Wanstrath on 8/22/11.
//  Copyright 2011 GitHub. All rights reserved.
//`

#import "AtomWindowController.h"

#import <WebKit/WebKit.h>
#import "JSCocoa.h"

@implementation AtomWindowController

@synthesize webView, URL;

- (id)initWithURL:(NSString *)_URL {
  self = [super initWithWindowNibName:@"AtomWindow"];
  self.URL = _URL;
  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];


  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomWindow"];

  if (self.URL) {
    [webView setMainFrameURL:self.URL];
  }
  else {
    jscocoa = [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
    [jscocoa setObject:self withName:@"WindowController"];

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *requirePath = [resourcePath stringByAppendingString:@"/src/require.js"];
    [jscocoa evalJSFile:requirePath];

    NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL *htmlURL = [resourceURL URLByAppendingPathComponent:@"static"];
    NSURL *indexURL = [htmlURL URLByAppendingPathComponent:@"index.html"];
    NSString *html = [NSString stringWithContentsOfURL:indexURL encoding:NSUTF8StringEncoding error:nil];
    [[webView mainFrame] loadHTMLString:html baseURL:htmlURL];
  }
}

-(BOOL) handleKeyEvent:(NSEvent *)event {
  // ICKY: Using a global function defined in App.js to deal with key events
  JSValueRef returnValue = [jscocoa callJSFunctionNamed:@"handleKeyEvent" withArguments:event, nil];
  return [jscocoa toBool:returnValue];
}

@end
