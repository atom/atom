#import "include/cef_application_mac.h"
#import "atom/client_handler.h"
#import "atom/atom_controller.h"

@implementation AtomController

@synthesize webView=_webView;

- (void)dealloc {
	[_webView release];
	[super dealloc];
}

- (id)init {
	self = [super initWithWindowNibName:@"AtomWindow"];
	
	_clientHandler = new ClientHandler();
  
  CefWindowInfo window_info;
  CefBrowserSettings settings;
  
  [self populateBrowserSettings:settings];
  
  window_info.SetAsChild(self.webView, self.webView.bounds.origin.x, self.webView.bounds.origin.y, self.webView.bounds.size.width, self.webView.bounds.size.height);
  CefBrowserHost::CreateBrowser(window_info, _clientHandler.get(), "http://reddit.com", settings);
	
	return self;
}

# pragma mark NSWindowDelegate

- (void)windowDidBecomeKey:(NSNotification*)notification {
  if (_clientHandler.get() && _clientHandler->GetBrowserId()) {
    _clientHandler->GetBrowser()->GetHost()->SetFocus(true);
  }
}

// Clean ourselves up after clearing the stack of anything that might have the window on it.
- (BOOL)windowShouldClose:(id)window {
	_clientHandler = NULL;
	
  [window autorelease];
  
  return YES;
}

- (void)populateBrowserSettings:(CefBrowserSettings &)settings {
  CefString(&settings.default_encoding) = "UTF-8";
  settings.remote_fonts_disabled = true;
  settings.encoding_detector_enabled = false;
  settings.javascript_disabled = false;
  settings.javascript_open_windows_disallowed = true;
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