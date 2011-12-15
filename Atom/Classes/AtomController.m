#import "AtomController.h"
#import "AtomApp.h"

#import "JSCocoa.h"
#import <WebKit/WebKit.h>

@interface AtomController ()
- (void)createWebView;

@property (nonatomic, retain) JSCocoa *jscocoa;
@property (nonatomic, retain, readwrite) NSString *url;
@property (nonatomic, retain, readwrite) NSString *bootstrapScript;
@end

@interface WebView (Atom)
- (id)inspector;
- (void)showConsole:(id)sender;
- (void)startDebuggingJavaScript:(id)sender;
@end

@implementation AtomController

@synthesize webView = _webView; 
@synthesize jscocoa = _jscocoa;
@synthesize url = _url;
@synthesize bootstrapScript = _bootstrapScript;

- (void)dealloc {
  [self.jscocoa unlinkAllReferences];
  [self.jscocoa garbageCollect];  
  self.jscocoa = nil;
  self.webView = nil;
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

- (id)initForSpecs {
  return [self initWithBootstrapScript:@"spec-bootstrap" url:nil];
}

- (id)initWithURL:(NSString *)url {
  return [self initWithBootstrapScript:@"bootstrap" url:url];
}

- (void)windowDidLoad {
  [super windowDidLoad];
  
  [self.window setDelegate:self];
  [self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
  
  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomController"];
  
  [self createWebView];  
}

- (BOOL)handleInputEvent:(NSEvent *)event {
  BOOL shouldReload = [event modifierFlags] & NSCommandKeyMask && [[event charactersIgnoringModifiers] hasPrefix:@"r"];
  if (shouldReload) {
    [self reload];
    return YES;    
  }
  
  if ([self.jscocoa hasJSFunctionNamed:@"handleKeyEvent"]) {
    JSValueRef handled = [self.jscocoa callJSFunctionNamed:@"handleKeyEvent" withArguments:event, nil];
    return [self.jscocoa toBool:handled];
  }
  
  return NO;
}

- (void)triggerAtomEventWithName:(NSString *)name data:(id)data {
   [self.jscocoa callJSFunctionNamed:@"triggerEvent" withArguments:name, data, false, nil];
}

- (void)createWebView {
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
  
  [[self.webView inspector] showConsole:self];
}

- (void)reload {
  [self.webView removeFromSuperview];
  [self createWebView];
}

- (void)close {
  [(AtomApp *)NSApp removeController:self]; 
  [super close];  
}

- (NSString *)projectPath {
  return PROJECT_DIR;
}

- (JSValueRefAndContextRef)jsWindow {
  JSValueRef window = [self.jscocoa evalJSString:@"window"]; 
  JSValueRefAndContextRef windowWithContext = {window, self.jscocoa.ctx};
  return windowWithContext;
}

#pragma mark NSWindowDelegate
- (BOOL)windowShouldClose:(id)sender {
  [self close];
  return YES;
}

#pragma mark WebUIDelegate
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
  return defaultMenuItems;
}

- (void)webViewClose:(WebView *)sender { // Triggered when closed from javascript
  [self close];
}

@end
