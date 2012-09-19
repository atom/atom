#import "include/cef_application_mac.h"
#include "include/cef_client.h"
#import "native/atom_cef_client.h"
#import "native/atom_window_controller.h"
#import "native/atom_application.h"

@implementation AtomWindowController

@synthesize splitView=_splitView;
@synthesize webView=_webView;
@synthesize devToolsView=_devToolsView;

- (void)dealloc {
  _cefClient = NULL;
  _cefDevToolsClient = NULL;
  [_webView release];
  [_bootstrapScript release];
  [_resourcePath release];
  [_pathToOpen release];
  [super dealloc];
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript background:(BOOL)background {
  self = [super initWithWindowNibName:@"AtomWindow"];
  _bootstrapScript = [bootstrapScript retain];

  AtomApplication *atomApplication = (AtomApplication *)[AtomApplication sharedApplication];
  _resourcePath = [[atomApplication.arguments objectForKey:@"resource-path"] retain];
  if (!_resourcePath) _resourcePath = [[[NSBundle mainBundle] resourcePath] retain];
  
    
  if (!background) {
    [self showWindow:self];
  }

  return self;
}

- (id)initWithPath:(NSString *)path {
  _pathToOpen = [path retain];
  return [self initWithBootstrapScript:@"window-bootstrap" background:NO];
}

- (id)initInBackground {
  [self initWithBootstrapScript:@"window-bootstrap" background:YES];
  [self.window setFrame:NSMakeRect(0, 0, 0, 0) display:NO];
  return self;
}

- (id)initSpecsThenExit:(BOOL)exitWhenDone {
  _runningSpecs = true;
  _exitWhenDone = exitWhenDone;
  return [self initWithBootstrapScript:@"spec-bootstrap" background:NO];
}

- (id)initBenchmarksThenExit:(BOOL)exitWhenDone {
  _runningSpecs = true;
  _exitWhenDone = exitWhenDone;
  return [self initWithBootstrapScript:@"benchmark-bootstrap" background:NO];
}

- (void)addBrowserToView:(NSView *)view url:(const char *)url cefHandler:(CefRefPtr<AtomCefClient>)cefClient {
  CefBrowserSettings settings;
  [self populateBrowserSettings:settings];
  CefWindowInfo window_info;
  window_info.SetAsChild(view, 0, 0, view.bounds.size.width, view.bounds.size.height);
  CefBrowserHost::CreateBrowser(window_info, cefClient.get(), url, settings);  
}

- (NSString *)encodeUrlParam:(NSString *)param {
  param = [param stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
  param = [param stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  return param;
}

- (void)windowDidLoad {
  [self.window setDelegate:self];

  NSURL *url = [[NSBundle mainBundle] resourceURL];
  NSMutableString *urlString = [NSMutableString string];
  [urlString appendString:[[url URLByAppendingPathComponent:@"static/index.html"] absoluteString]];
  [urlString appendFormat:@"?bootstrapScript=%@", [self encodeUrlParam:_bootstrapScript]];
  [urlString appendFormat:@"&resourcePath=%@", [self encodeUrlParam:_resourcePath]];
  if (_exitWhenDone)
    [urlString appendString:@"&exitWhenDone=1"];
  if (_pathToOpen)
    [urlString appendFormat:@"&pathToOpen=%@", [self encodeUrlParam:_pathToOpen]];

  _cefClient = new AtomCefClient();
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
    _devToolsView = [[NSView alloc] initWithFrame:_splitView.bounds];
    [_splitView addSubview:_devToolsView];
    [_splitView adjustSubviews];
    [self performSelector:@selector(attachDevTools) withObject:nil afterDelay:0];
  }
}

// If this is run directly after adding _devToolsView to _splitView, the
// devtools don't resize properly.
// HACK: I hate this and want to place this code directly in showDevTools
- (void)attachDevTools {
  _cefDevToolsClient = new AtomCefClient();
  std::string devtools_url = _cefClient->GetBrowser()->GetHost()->GetDevToolsURL(true);
  [self addBrowserToView:_devToolsView url:devtools_url.c_str() cefHandler:_cefDevToolsClient];
}

- (void)hideDevTools {
  [_devToolsView removeFromSuperview];
  [_splitView adjustSubviews];
  [_devToolsView release];
  _devToolsView = nil;
  _cefDevToolsClient = NULL;
  _cefClient->GetBrowser()->GetHost()->SetFocus(true);
}

# pragma mark NSWindowDelegate

- (void)windowDidResignMain:(NSNotification *)notification {
  if (_cefClient && _cefClient->GetBrowser() && !_runningSpecs) {
    _cefClient->GetBrowser()->GetHost()->SetFocus(false);
  }
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
  if (_cefClient && _cefClient->GetBrowser()) {
    _cefClient->GetBrowser()->GetHost()->SetFocus(true);
  }
}

- (BOOL)windowShouldClose:(id)window {
  [self autorelease];
  return YES;
}

- (void)populateBrowserSettings:(CefBrowserSettings &)settings {
  CefString(&settings.default_encoding) = "UTF-8";
  settings.remote_fonts_disabled = true;
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
  settings.web_security_disabled = false;
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
  settings.accelerated_painting_enabled = true;
  settings.accelerated_filters_enabled = true;
  settings.accelerated_plugins_disabled = false;
  settings.developer_tools_disabled = false;
  settings.fullscreen_enabled = true;
}

@end
