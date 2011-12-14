#import "AtomController.h"
#import "AtomApp.h"

#import "JSCocoa.h"
#import <WebKit/WebKit.h>

@interface AtomController ()

@property (nonatomic, retain, readwrite) NSString *url;
@property (nonatomic, retain, readwrite) NSString *bootstrapScript;

@end

@implementation AtomController

@synthesize 
  webView = _webView, 
  jscocoa = _jscocoa,
  url = _url,
  bootstrapScript = _bootstrapScript;

- (void)dealloc {
  [self.jscocoa unlinkAllReferences];
  [self.jscocoa garbageCollect];  
  self.jscocoa = nil;
  self.webView = nil;;
  self.bootstrapScript = nil;
  self.url = nil;

  [super dealloc];
}


- (id)initWithBootstrapScript:(NSString *)bootstrapScript url:(NSString *)url {
  self = [super initWithWindowNibName:@"AtomWindow"];
  self.bootstrapScript = bootstrapScript;
  self.url = url;
  
  [self.window makeKeyWindow];
  return self;
}

- (id)initSpecs {
  return [self initWithBootstrapScript:@"spec-startup" url:nil];
}

- (id)initWithURL:(NSString *)url {
  return [self initWithBootstrapScript:@"startup" url:url];
}

- (void)createWebView {
  [self.webView removeFromSuperview];
  
  self.webView = [[WebView alloc] initWithFrame:[self.window.contentView frame]];
  [self.webView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [self.window.contentView addSubview:self.webView];  
  [self.webView setUIDelegate:self];

  self.jscocoa = [[JSCocoa alloc] initWithGlobalContext:[[self.webView mainFrame] globalContext]];
  [self.jscocoa setObject:self withName:@"$atomController"];
  [self.jscocoa setObject:self.bootstrapScript withName:@"$bootstrapScript"];
  
  NSURL *resourceDirURL = [[NSBundle mainBundle] resourceURL];
  NSURL *indexURL = [resourceDirURL URLByAppendingPathComponent:@"index.html"];
  
  NSURLRequest *request = [NSURLRequest requestWithURL:indexURL]; 
  [[self.webView mainFrame] loadRequest:request];
}

- (void)windowDidLoad {
  [super windowDidLoad];

  [self.window setDelegate:self];
  [self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomController"];

  [self createWebView];  
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
