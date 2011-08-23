//
//  AtomWindowController.m
//  Atomicity
//
//  Created by Chris Wanstrath on 8/22/11.
//  Copyright 2011 GitHub. All rights reserved.
//

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
  
  [self setShouldCascadeWindows:NO];
  [self setWindowFrameAutosaveName:@"atomWindow"];
  
  if (self.URL) {
    [webView setMainFrameURL:self.URL];
  } else {
    id path = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];    
    id html = [[NSString alloc] initWithContentsOfURL:path];
    [[webView mainFrame] loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];  
  }
  
  // https://github.com/parmanoir/jscocoa#readme
  JSCocoa* jsc = [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
  [jsc setObject:self withName:@"App"];
}

@end
