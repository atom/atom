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
  aPath = aPath ? aPath : @"/tmp";
    
  self = [super initWithWindowNibName:@"AtomWindow"];
  path = [[aPath stringByStandardizingPath] retain];

  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];
  
  [[webView inspector] showConsole:self];
  
  [self.window setDelegate:self];
    
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

// Helper methods that should go elsewhere
- (NSString *)tempfile {
  char *directory = "/tmp";
  char *prefix = "temp-file";
  char *tmpPath = tempnam(directory, prefix);
  NSString *tmpPathString = [NSString stringWithUTF8String:tmpPath];
  free(tmpPath);
  
  return tmpPathString;
}

// WebUIDelegate
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
  return defaultMenuItems;
}

// WindowDelegate
- (BOOL)windowShouldClose:(id)sender {
  [(AtomApp *)NSApp removeController:self];
  return YES;
}

@end
