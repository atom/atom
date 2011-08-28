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
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *bootstrapPath = [resourcePath stringByAppendingString:@"/src/bootstrap.js"];
    NSString *coffeePath = [resourcePath stringByAppendingString:@"/vendor/coffee-script.js"];    
    JSCocoa* jsc = [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
    [jsc setObject:self withName:@"WindowController"];
    [jsc evalJSFile:bootstrapPath];
    [jsc evalJSFile:coffeePath];    

    NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL *htmlURL = [resourceURL URLByAppendingPathComponent:@"static"];
    NSURL *indexURL = [htmlURL URLByAppendingPathComponent:@"index.html"];
    NSString *html = [NSString stringWithContentsOfURL:indexURL encoding:NSUTF8StringEncoding error:nil];
    [[webView mainFrame] loadHTMLString:html baseURL:htmlURL]; 
  }
}


@end
