#import "include/cef_application_mac.h"
#import "atom/client_handler.h"
#import "atom/cefclient_mac.h"

// The global ClientHandler reference.
extern CefRefPtr<ClientHandler> g_handler;

@implementation ClientApplication

+ (id)sharedApplication {
  id atomApp = [super sharedApplication];
  
  CefSettings settings;
  [self populateAppSettings:settings];
  
  CefMainArgs mainArgs(0, NULL);
  CefRefPtr<CefApp> app;

  CefInitialize(mainArgs, settings, app.get());
  
  return atomApp;
}
   
+ (void)populateAppSettings:(CefSettings &)settings {
  CefString(&settings.cache_path) = "";
  CefString(&settings.user_agent) = "";
  CefString(&settings.log_file) = "";
  CefString(&settings.javascript_flags) = "";
 
  settings.log_severity = LOGSEVERITY_ERROR;
}


// Create the application on the UI thread.
- (void)createWindow {
  // Create the main application window.
  NSRect window_rect = { {0, 0}, {800, 800} };
  NSWindow* mainWnd = [[UnderlayOpenGLHostingWindow alloc]
                       initWithContentRect:window_rect
                       styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask )
                       backing:NSBackingStoreBuffered
                       defer:NO];
  [mainWnd setTitle:@"cefclient"];
  [mainWnd setDelegate:self];
  
  // Rely on the window delegate to clean us up rather than immediately
  // releasing when the window gets closed. We use the delegate to do
  // everything from the autorelease pool so the window isn't on the stack
  // during cleanup (ie, a window close from javascript).
  [mainWnd setReleasedWhenClosed:NO];
  
  NSView* contentView = [mainWnd contentView];
  
  // Create the handler.
  g_handler = new ClientHandler();
  g_handler->SetMainHwnd(contentView);
  
  // Create the browser view.
  CefWindowInfo window_info;
  CefBrowserSettings settings;
  
  [self populateBrowserSettings:settings];
  
  window_info.SetAsChild(contentView, window_rect.origin.x, window_rect.origin.y, window_rect.size.width, window_rect.size.height);
  CefBrowserHost::CreateBrowser(window_info, g_handler.get(), g_handler->GetStartupURL(), settings);
  
  [mainWnd makeKeyAndOrderFront:nil];  
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

# pragma mark NSApplicationDelegate

// Sent by the default notification center immediately before the application terminates.
- (void)applicationWillTerminate:(NSNotification *)notification {  
  g_handler = NULL; // Shut down CEF.
  CefShutdown();
  [self release];
}

# pragma mark CefAppProtocol

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent sendingEventScoper;
  [super sendEvent:event];
}

# pragma mark NSWindowDelegate

- (void)windowDidBecomeKey:(NSNotification*)notification {
  if (g_handler.get() && g_handler->GetBrowserId()) {
    g_handler->GetBrowser()->GetHost()->SetFocus(true);
  }
}

// Clean ourselves up after clearing the stack of anything that might have the window on it.
- (BOOL)windowShouldClose:(id)window {
  [window autorelease];
  
  return YES;
}

@end



