#import "AtomController.h"
#import "AtomApp.h"

#import "JSCocoa.h"
#import <WebKit/WebKit.h>

@interface AtomController ()

@property (nonatomic, retain, readwrite) NSString *url;
@property (nonatomic, retain, readwrite) NSString *bootstrapPage;

@end

@implementation AtomController

@synthesize 
  webView = _webView, 
  jscocoa = _jscocoa,
  url = _url,
  bootstrapPage = _bootstrapPage;

- (void)dealloc {
  [self.jscocoa unlinkAllReferences];
  [self.jscocoa garbageCollect];  
  self.jscocoa = nil;
  self.webView = nil;
  self.bootstrapPage = nil;
  self.url = nil;

  [super dealloc];
}


- (id)initWithBootstrapPage:(NSString *)bootstrapPage url:(NSString *)url {
  self = [super initWithWindowNibName:@"AtomWindow"];
  self.bootstrapPage = bootstrapPage;
  self.url = url;
  
  [self.window makeKeyWindow];
  return self;
}


- (id)initForSpecs {
  return [self initWithBootstrapPage:@"spec-suite.html" url:nil];
}

- (id)initWithURL:(NSString *)url {
  return [self initWithBootstrapPage:@"index.html" url:url];
}

- (void)windowDidLoad {
  [super windowDidLoad];

  [self.window setDelegate:self];
  [self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

  [self.webView setUIDelegate:self];

  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomController"];

  self.jscocoa = [[JSCocoa alloc] initWithGlobalContext:[[self.webView mainFrame] globalContext]];
  [self.jscocoa setObject:self withName:@"$atomController"];

  NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
  NSURL *bootstrapPageURL = [resourceURL URLByAppendingPathComponent:self.bootstrapPage];
    
  NSURLRequest *request = [NSURLRequest requestWithURL:bootstrapPageURL];
  [[self.webView mainFrame] loadRequest:request];
}


- (void)close {
  [(AtomApp *)NSApp removeController:self];
  [super close];  
}

- (NSString *)projectPath {
  return PROJECT_DIR;
}

// WebUIDelegate
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
  return defaultMenuItems;
}

@end
