#import "AtomController.h"
#import "AtomApp.h"

#import "JSCocoa.h"

#import <WebKit/WebKit.h>
#import <stdio.h>

@implementation AtomController

@synthesize webView, path, jscocoa;

- (void)dealloc {
  [jscocoa unlinkAllReferences];
  [jscocoa garbageCollect];
  [jscocoa release]; jscocoa = nil;

  [webView release];
  [path release];

  [super dealloc];
}

- (id)initWithPath:(NSString *)aPath {
  self = [super initWithWindowNibName:@"AtomWindow"];
  [self setPath:[aPath stringByStandardizingPath]];

  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];
  
  [webView setUIDelegate:self];

  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomController"];

  jscocoa =   [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
  [jscocoa setObject:self withName:@"atomController"];

  NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
  NSURL *indexURL = [resourceURL URLByAppendingPathComponent:@"index.html"];
  NSURLRequest *request = [NSURLRequest requestWithURL:indexURL];
  [[webView mainFrame] loadRequest:request];    
}

- (void)close {
  [(AtomApp *)NSApp removeController:self];
  [super close];
}

- (NSString *)tempfile {
  char *directory = "/tmp";
  char *prefix = "temp-file";
  char *tmpPath = tempnam(directory, prefix);
  NSString *tmpPathString = [NSString stringWithUTF8String:tmpPath];
  free(tmpPath);
  
  return tmpPathString;
}

// WebUIDelegate Protocol
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
  return defaultMenuItems;
}

@end
