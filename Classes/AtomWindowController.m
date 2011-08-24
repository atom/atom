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
    
  [webView setFrameLoadDelegate:self];
    
  if (self.URL) {
    [webView setMainFrameURL:self.URL];
  } else {
    NSURL *bundleURL = [[NSBundle mainBundle] resourceURL];
    NSURL *htmlURL = [bundleURL URLByAppendingPathComponent:@"HTML"];
    NSURL *indexURL = [htmlURL URLByAppendingPathComponent:@"index.html"];
    NSString *html = [NSString stringWithContentsOfURL:indexURL encoding:NSUTF8StringEncoding error:nil];
    [[webView mainFrame] loadHTMLString:html baseURL:htmlURL];  
  }
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
    // https://github.com/parmanoir/jscocoa#readme
    JSCocoa* jsc = [[JSCocoa alloc] initWithGlobalContext:[frame globalContext]];
    [jsc setObject:self withName:@"App"];
}


@end
