#import "include/cef_application_mac.h"
#import "native/atom_cef_client.h"
#import "native/atom_window_controller.h"

@implementation AtomWindowController

@synthesize webView=_webView;

- (void)dealloc {
	[_webView release];
	[_bootstrapScript release];
  [_pathToOpen release];
	[super dealloc];
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript {
	self = [super initWithWindowNibName:@"AtomWindow"];

	_bootstrapScript = [bootstrapScript retain];

  [self showWindow:self];
}

- (id)initWithPath:(NSString *)path {
  _pathToOpen = [path retain];
  return [self initWithBootstrapScript:@"window-bootstrap"];
}

- (id)initSpecs {
  _runningSpecs = true;
  return [self initWithBootstrapScript:@"spec-bootstrap"];
}

- (id)initBenchmarks {
  return [self initWithBootstrapScript:@"benchmark-bootstrap"];
}

- (void)windowDidLoad {
  [self.window setDelegate:self];
  
  _cefClient = new AtomCefClient();
  
  CefBrowserSettings settings;
  [self populateBrowserSettings:settings];
  
  CefWindowInfo window_info;  
  window_info.SetAsChild(self.webView, 0, 0, self.webView.bounds.size.width, self.webView.bounds.size.height);
  
  NSURL *url = [[NSBundle mainBundle] resourceURL];
  NSString *urlString = [[url URLByAppendingPathComponent:@"static/index.html"] absoluteString];
  urlString = [urlString stringByAppendingFormat:@"?windowNumber=%d&bootstrapScript=%@&pathToOpen=%@",
               [self.window windowNumber],
               [_bootstrapScript stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
               [_pathToOpen stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
  CefBrowserHost::CreateBrowser(window_info, _cefClient.get(), [urlString UTF8String], settings);
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