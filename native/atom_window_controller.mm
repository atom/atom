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
  [_bootstrapScript release];
  [_resourcePath release];
  [_pathToOpen release];

  _cefClient = NULL;
  _cefDevToolsClient = NULL;

  [super dealloc];
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript background:(BOOL)background alwaysUseBundleResourcePath:(BOOL)alwaysUseBundleResourcePath {
  self = [super initWithWindowNibName:@"AtomWindow"];
  _bootstrapScript = [bootstrapScript retain];

  AtomApplication *atomApplication = (AtomApplication *)[AtomApplication sharedApplication];

  _resourcePath = [atomApplication.arguments objectForKey:@"resource-path"];
  if (!alwaysUseBundleResourcePath && !_resourcePath) {
    NSString *defaultRepositoryPath = [@"~/github/atom" stringByStandardizingPath];
    if ([defaultRepositoryPath characterAtIndex:0] == '/') {
      BOOL isDir = false;
      BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:defaultRepositoryPath isDirectory:&isDir];
      if (isDir && exists)
        _resourcePath = defaultRepositoryPath;
    }
  }

  if (alwaysUseBundleResourcePath || !_resourcePath) {
    _resourcePath = [[NSBundle bundleForClass:self.class] resourcePath];
  }

  if ([self isDevMode]) {
    [self displayDevIcon];
  }

  _resourcePath = [_resourcePath stringByStandardizingPath];
  [_resourcePath retain];

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
  return [self initWithBootstrapScript:@"window-bootstrap" background:NO alwaysUseBundleResourcePath:useBundleResourcePath];
}

- (id)initDevWithPath:(NSString *)path {
  _pathToOpen = [path retain];
  return [self initWithBootstrapScript:@"window-bootstrap" background:NO alwaysUseBundleResourcePath:false];
}

- (id)initInBackground {
  AtomApplication *atomApplication = (AtomApplication *)[AtomApplication sharedApplication];
  BOOL useBundleResourcePath = [atomApplication.arguments objectForKey:@"dev"] == nil;

  [self initWithBootstrapScript:@"window-bootstrap" background:YES alwaysUseBundleResourcePath:useBundleResourcePath];
  [self.window setFrame:NSMakeRect(0, 0, 0, 0) display:NO];
  [self.window setExcludedFromWindowsMenu:YES];
  [self.window setCollectionBehavior:NSWindowCollectionBehaviorStationary];
  return self;
}

- (id)initSpecsThenExit:(BOOL)exitWhenDone {
  _runningSpecs = true;
  _exitWhenDone = exitWhenDone;
  return [self initWithBootstrapScript:@"spec-bootstrap" background:NO alwaysUseBundleResourcePath:NO];
}

- (id)initBenchmarksThenExit:(BOOL)exitWhenDone {
  _runningSpecs = true;
  _exitWhenDone = exitWhenDone;
  return [self initWithBootstrapScript:@"benchmark-bootstrap" background:NO alwaysUseBundleResourcePath:NO];
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
  NSURL *url = [[NSBundle bundleForClass:self.class] resourceURL];
  NSMutableString *urlString = [NSMutableString string];
  [urlString appendString:[[url URLByAppendingPathComponent:@"static/index.html"] absoluteString]];
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

  NSButton *devButton = [[NSButton alloc] init];
  [devButton setTitle:@"\xF0\x9F\x92\x80"];
  devButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  devButton.buttonType = NSMomentaryChangeButton;
  devButton.bordered = NO;
  [devButton sizeToFit];
  devButton.frame = NSMakeRect(fullScreenButton.frame.origin.x - devButton.frame.size.width - 5, fullScreenButton.frame.origin.y, devButton.frame.size.width, devButton.frame.size.height);

  [[self.window.contentView superview] addSubview:devButton];
}

- (void)populateBrowserSettings:(CefBrowserSettings &)settings {
  CefString(&settings.default_encoding) = "UTF-8";
  settings.remote_fonts_disabled = false;
  settings.encoding_detector_enabled = false;
  settings.javascript_disabled = false;
  settings.javascript_open_windows_disallowed = false;
  settings.javascript_close_windows_disallowed = false;
  settings.javascript_access_clipboard_disallowed = false;
  settings.dom_paste_disabled = true;
  settings.caret_browsing_enabled = false;
  settings.java_disabled = true;
  settings.plugins_disabled = true;
  settings.universal_access_from_file_urls_allowed = false;
  settings.file_access_from_file_urls_allowed = false;
  settings.web_security_disabled = true;
  settings.xss_auditor_enabled = true;
  settings.image_load_disabled = false;
  settings.shrink_standalone_images_to_fit = false;
  settings.site_specific_quirks_disabled = false;
  settings.text_area_resize_disabled = false;
  settings.page_cache_disabled = true;
  settings.tab_to_links_disabled = true;
  settings.hyperlink_auditing_disabled = true;
  settings.user_style_sheet_enabled = false;
  settings.author_and_user_styles_disabled = false;
  settings.local_storage_disabled = false;
  settings.databases_disabled = false;
  settings.application_cache_disabled = false;
  settings.webgl_disabled = false;
  settings.accelerated_compositing_disabled = false;
  settings.accelerated_layers_disabled = false;
  settings.accelerated_video_disabled = false;
  settings.accelerated_2d_canvas_disabled = false;
//   settings.accelerated_painting_enabled = true;
//   settings.accelerated_filters_enabled = true;
  settings.accelerated_plugins_disabled = false;
  settings.developer_tools_disabled = false;
//   settings.fullscreen_enabled = true;
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
