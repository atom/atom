#import "AtomController.h"
#import "AtomApp.h"

#import "JSCocoa.h"

#import <WebKit/WebKit.h>

@implementation AtomController

@synthesize webView, url, jscocoa;

- (void)dealloc {
  [jscocoa unlinkAllReferences];
  [jscocoa garbageCollect];
  [jscocoa release]; jscocoa = nil;

  [webView release];
  [url release];

  [super dealloc];
}

- (id)initWithURL:(NSString *)_url {
  self = [super initWithWindowNibName:@"AtomWindow"];
  url = [_url retain];

  [self.window makeKeyWindow];
  
  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];

  [self.window setDelegate:self];
  [self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

  [webView setUIDelegate:self];

  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomController"];

  jscocoa =   [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
  [jscocoa setObject:self withName:@"$atomController"];

  NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
  NSURL *indexURL = [resourceURL URLByAppendingPathComponent:@"index.html"];
  NSURLRequest *request = [NSURLRequest requestWithURL:indexURL];
  [[webView mainFrame] loadRequest:request];
}

- (void)reload {
  [(AtomApp *)NSApp reloadController:self];
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
