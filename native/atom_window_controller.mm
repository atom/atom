#import "include/cef_application_mac.h"
#import "include/cef_client.h"
#import "native/atom_cef_client.h"
#import "native/atom_window_controller.h"
#import "native/atom_application.h"
#import <signal.h>

@implementation AtomWindowController

@synthesize splitView=_splitView;
@synthesize webView=_webView;
@synthesize devToolsView=_devToolsView;
@synthesize pathToOpen=_pathToOpen;

- (void)dealloc {
  [_splitView release];
  [_devToolsView release];
  [_webView release];
  [_devButton release];
  [_bootstrapScript release];
  [_resourcePath release];
  [_pathToOpen release];

  _cefClient = NULL;
  _cefDevToolsClient = NULL;

  [super dealloc];
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript background:(BOOL)background useBundleResourcePath:(BOOL)useBundleResourcePath {
  self = [super initWithWindowNibName:@"AtomWindow"];
  _bootstrapScript = [bootstrapScript retain];

  AtomApplication *atomApplication = (AtomApplication *)[AtomApplication sharedApplication];

  if (useBundleResourcePath) {
    _resourcePath = [[NSBundle bundleForClass:self.class] resourcePath];
  }
  else {
    _resourcePath = [[atomApplication.arguments objectForKey:@"resource-path"] stringByStandardizingPath];
    if (!_resourcePath) {
      NSString *defaultRepositoryPath = [@"~/github/atom" stringByStandardizingPath];
      if ([defaultRepositoryPath characterAtIndex:0] == '/') {
        BOOL isDir = false;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:defaultRepositoryPath isDirectory:&isDir];
        if (isDir && exists) {
          _resourcePath = defaultRepositoryPath;
        }
        else {
          NSLog(@"Warning: No resource path specified and no directory exists at ~/github/atom");
        }
      }
    }
  }

  if ([self isDevMode]) {
    [self displayDevIcon];
  }

  _resourcePath = [_resourcePath stringByStandardizingPath];
  [_resourcePath retain];

  NSMutableArray *paths = [NSMutableArray arrayWithObjects:
                            @"src/stdlib",
                            @"src/app",
                            @"src/packages",
                            @"src",
                            @"vendor",
                            @"static",
                            @"node_modules",
                            nil];
  NSMutableArray *resourcePaths = [[NSMutableArray alloc] init];

  if (_runningSpecs) {
    [paths insertObject:@"benchmark" atIndex:0];
    [paths insertObject:@"spec" atIndex:0];
    NSString *fixturePackagesDirectory = [NSString stringWithFormat:@"%@/spec/fixtures/packages", _resourcePath];
    [resourcePaths addObject:fixturePackagesDirectory];
  }

  NSString *userPackagesDirectory = [@"~/.atom/packages" stringByStandardizingPath];
  [resourcePaths addObject:userPackagesDirectory];

  for (int i = 0; i < paths.count; i++) {
    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", _resourcePath, [paths objectAtIndex:i]];
    [resourcePaths addObject:fullPath];
  }
  [resourcePaths addObject:_resourcePath];

  NSString *nodePath = [resourcePaths componentsJoinedByString:@":"];
  setenv("NODE_PATH", [nodePath UTF8String], TRUE);

  if (!background) {
    [self setShouldCascadeWindows:NO];
    [self setWindowFrameAutosaveName:@"AtomWindow"];
    NSColor *background = [NSColor colorWithDeviceRed:(51.0/255.0) green:(51.0/255.0f) blue:(51.0/255.0f) alpha:1.0];
    [self.window setBackgroundColor:background];
    [self showWindow:self];
  }

  return self;
}

- (id)initWithPath:(NSString *)path {
  _pathToOpen = [path retain];
  AtomApplication *atomApplication = (AtomApplication *)[AtomApplication sharedApplication];
  BOOL useBundleResourcePath = [atomApplication.arguments objectForKey:@"dev"] == nil;
  return [self initWithBootstrapScript:@"window-bootstrap" background:NO useBundleResourcePath:useBundleResourcePath];
}

- (id)initDevWithPath:(NSString *)path {
  _pathToOpen = [path retain];
  return [self initWithBootstrapScript:@"window-bootstrap" background:NO useBundleResourcePath:false];
}

- (id)initInBackground {
  AtomApplication *atomApplication = (AtomApplication *)[AtomApplication sharedApplication];
  BOOL useBundleResourcePath = [atomApplication.arguments objectForKey:@"dev"] == nil;

  [self initWithBootstrapScript:@"window-bootstrap" background:YES useBundleResourcePath:useBundleResourcePath];
  [self.window setFrame:NSMakeRect(0, 0, 0, 0) display:NO];
  [self.window setExcludedFromWindowsMenu:YES];
  [self.window setCollectionBehavior:NSWindowCollectionBehaviorStationary];
  return self;
}

- (id)initSpecsThenExit:(BOOL)exitWhenDone {
  _runningSpecs = true;
  _exitWhenDone = exitWhenDone;
  return [self initWithBootstrapScript:@"spec-bootstrap" background:NO useBundleResourcePath:NO];
}

- (id)initBenchmarksThenExit:(BOOL)exitWhenDone {
  _runningSpecs = true;
  _exitWhenDone = exitWhenDone;
  return [self initWithBootstrapScript:@"benchmark-bootstrap" background:NO useBundleResourcePath:NO];
}

- (void)addBrowserToView:(NSView *)view url:(const char *)url cefHandler:(CefRefPtr<AtomCefClient>)cefClient {
  CefBrowserSettings settings;
  [self populateBrowserSettings:settings];
  CefWindowInfo window_info;
  window_info.SetAsChild(view, 0, 0, view.bounds.size.width, view.bounds.size.height);
  CefBrowserHost::CreateBrowser(window_info, cefClient.get(), url, settings);
}

- (NSString *)encodeUrlParam:(NSString *)param {
  param = [param stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  param = [param stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
  return param;
}

- (void)windowDidLoad {
  [self.window setDelegate:self];
  [self performSelector:@selector(attachWebView) withObject:nil afterDelay:0];
}

// If this is run directly in windowDidLoad, the web view doesn't
// have the correct initial size based on the frame's last stored size.
// HACK: I hate this and want to place this code directly in windowDidLoad
- (void)attachWebView {
  NSMutableString *urlString = [NSMutableString string];

  NSURL *indexUrl = [[NSURL alloc] initFileURLWithPath:[_resourcePath stringByAppendingPathComponent:@"static/index.html"]];
  [urlString appendString:[indexUrl absoluteString]];
  [urlString appendFormat:@"?bootstrapScript=%@", [self encodeUrlParam:_bootstrapScript]];
  [urlString appendFormat:@"&resourcePath=%@", [self encodeUrlParam:_resourcePath]];
  if ([self isDevMode])
    [urlString appendFormat:@"&devMode=1"];
  if (_exitWhenDone)
    [urlString appendString:@"&exitWhenDone=1"];
  if (_pathToOpen)
    [urlString appendFormat:@"&pathToOpen=%@", [self encodeUrlParam:_pathToOpen]];

  _cefClient = new AtomCefClient();
  [self.webView setHidden:YES];
  [self addBrowserToView:self.webView url:[urlString UTF8String] cefHandler:_cefClient];
}

- (void)toggleDevTools {
  if (_devToolsView) {
    [self hideDevTools];
  }
  else {
    [self showDevTools];
  }
}

- (void)showDevTools {
  if (_devToolsView) return;

  if (_cefClient && _cefClient->GetBrowser()) {
    NSRect webViewFrame = _webView.frame;
    NSRect devToolsViewFrame = _webView.frame;
    devToolsViewFrame.size.height = NSHeight(webViewFrame) / 3;
    webViewFrame.size.height = NSHeight(webViewFrame) - NSHeight(devToolsViewFrame);
    [_webView setFrame:webViewFrame];
    _devToolsView = [[NSView alloc] initWithFrame:devToolsViewFrame];

    [_splitView addSubview:_devToolsView];
    [_splitView adjustSubviews];

    _cefDevToolsClient = new AtomCefClient(true, true);
    std::string devtools_url = _cefClient->GetBrowser()->GetHost()->GetDevToolsURL(true);
    [self addBrowserToView:_devToolsView url:devtools_url.c_str() cefHandler:_cefDevToolsClient];
  }
}

- (void)hideDevTools {
  [_devToolsView removeFromSuperview];
  [_splitView adjustSubviews];
  [_devToolsView release];
  _devToolsView = nil;
  _cefDevToolsClient = NULL;
  _cefClient->GetBrowser()->GetHost()->SetFocus(true);
}

- (void)setPidToKillOnClose:(NSNumber *)pid {
  _pidToKillOnClose = [pid retain];
}

# pragma mark NSWindowDelegate


- (void)windowDidResignMain:(NSNotification *)notification {
  if (!_runningSpecs) {
    [self.window makeFirstResponder:nil];
  }
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
  if (_cefClient && _cefClient->GetBrowser()) {
    _cefClient->GetBrowser()->GetHost()->SetFocus(true);
  }
}

- (BOOL)windowShouldClose:(NSNotification *)notification {
  if (_cefClient && _cefClient->GetBrowser()) {
    _cefClient->GetBrowser()->SendProcessMessage(PID_RENDERER, CefProcessMessage::Create("shutdown"));
  }

  if (_pidToKillOnClose) kill([_pidToKillOnClose intValue], SIGQUIT);

  [self autorelease];
  return YES;
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
  if (_devButton)
    [_devButton setHidden:YES];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
  if (_devButton)
    [_devButton setHidden:NO];
}

- (bool)isDevMode {
  NSString *bundleResourcePath = [[NSBundle bundleForClass:self.class] resourcePath];
  return ![_resourcePath isEqualToString:bundleResourcePath];
}

- (void)displayDevIcon {
  NSView *themeFrame = [self.window.contentView superview];
  NSButton *fullScreenButton = nil;
  for (NSView *view in themeFrame.subviews) {
    if (![view isKindOfClass:NSButton.class]) continue;
    NSButton *button = (NSButton *)view;
    if (button.action != @selector(toggleFullScreen:)) continue;
    fullScreenButton = button;
    break;
  }

  _devButton = [[NSButton alloc] init];
  [_devButton setTitle:@"\xF0\x9F\x92\x80"];
  _devButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  _devButton.buttonType = NSMomentaryChangeButton;
  _devButton.bordered = NO;
  [_devButton sizeToFit];
  _devButton.frame = NSMakeRect(fullScreenButton.frame.origin.x - _devButton.frame.size.width - 5, fullScreenButton.frame.origin.y, _devButton.frame.size.width, _devButton.frame.size.height);

  [[self.window.contentView superview] addSubview:_devButton];
}

- (void)populateBrowserSettings:(CefBrowserSettings &)settings {
  CefString(&settings.default_encoding) = "UTF-8";
  settings.remote_fonts = STATE_ENABLED;
  settings.javascript = STATE_ENABLED;
  settings.javascript_open_windows = STATE_ENABLED;
  settings.javascript_close_windows = STATE_ENABLED;
  settings.javascript_access_clipboard = STATE_ENABLED;
  settings.javascript_dom_paste = STATE_DISABLED;
  settings.caret_browsing = STATE_DISABLED;
  settings.java = STATE_DISABLED;
  settings.plugins = STATE_DISABLED;
  settings.universal_access_from_file_urls = STATE_DISABLED;
  settings.file_access_from_file_urls = STATE_DISABLED;
  settings.web_security = STATE_DISABLED;
  settings.image_loading = STATE_ENABLED;
  settings.image_shrink_standalone_to_fit = STATE_DISABLED;
  settings.text_area_resize = STATE_ENABLED;
  settings.page_cache = STATE_DISABLED;
  settings.tab_to_links = STATE_DISABLED;
  settings.author_and_user_styles = STATE_ENABLED;
  settings.local_storage = STATE_ENABLED;
  settings.databases = STATE_ENABLED;
  settings.application_cache = STATE_ENABLED;
  settings.webgl = STATE_ENABLED;
  settings.accelerated_compositing = STATE_ENABLED;
  settings.developer_tools = STATE_ENABLED;
}

@end

@interface GraySplitView : NSSplitView
- (NSColor*)dividerColor;
@end

@implementation GraySplitView
- (NSColor*)dividerColor {
  return [NSColor darkGrayColor];
}
@end
