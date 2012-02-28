#import "AtomController.h"

#import "include/cef.h"
#import "client_handler.h"
#import "native_handler.h"

@implementation AtomController

@synthesize webView=_webView;

- (void)dealloc {
  [_bootstrapScript release];

  [super dealloc];
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript appContext:(CefRefPtr<CefV8Context>)appContext {
  self = [super initWithWindowNibName:@"ClientWindow"];
  _bootstrapScript = [bootstrapScript retain];
  _appContext = appContext;
  
  [self createBrowser];
  [self.window makeKeyAndOrderFront:nil];
    
  return self;
}

- (id)initSpecsWithAppContext:(CefRefPtr<CefV8Context>)appContext {
  return [self initWithBootstrapScript:@"spec-bootstrap" appContext:appContext];
}

- (void)createBrowser {
  [self.window setDelegate:self];  
  [self.window setReleasedWhenClosed:NO];
  
  _handler = new ClientHandler(self);
  
  CefWindowInfo window_info;
  CefBrowserSettings settings;
  
  AppGetBrowserSettings(settings);
  
  window_info.SetAsChild(self.webView, 0, 0, self.webView.bounds.size.width, self.webView.bounds.size.height);
  
  NSURL *resourceDirURL = [[NSBundle mainBundle] resourceURL];
  NSString *indexURLString = [[resourceDirURL URLByAppendingPathComponent:@"index.html"] absoluteString];
  CefBrowser::CreateBrowser(window_info, _handler.get(), [indexURLString UTF8String], settings);  
}

- (void)afterCreated:(CefRefPtr<CefBrowser>) browser {
  browser->ShowDevTools();
  
  CefRefPtr<CefFrame> frame = browser->GetMainFrame();
  CefRefPtr<CefV8Context> context = frame->GetV8Context();
  CefRefPtr<CefV8Value> global = context->GetGlobal();
  
  context->Enter();
  
  global->SetValue("$app", _appContext->GetGlobal(), V8_PROPERTY_ATTRIBUTE_NONE);
  
  CefRefPtr<CefV8Value> bootstrapScript = CefV8Value::CreateString([_bootstrapScript UTF8String]);
  global->SetValue("$bootstrapScript", bootstrapScript, V8_PROPERTY_ATTRIBUTE_NONE);
  
  CefRefPtr<CefV8Value> pathToOpen = CefV8Value::CreateString("~/");
  global->SetValue("$pathToOpen", pathToOpen, V8_PROPERTY_ATTRIBUTE_NONE);

  // $atom
  CefRefPtr<CefV8Value> atom = CefV8Value::CreateObject(NULL);  
  CefRefPtr<CefV8Value> loadPath = CefV8Value::CreateString(PROJECT_DIR);
  atom->SetValue("loadPath", loadPath, V8_PROPERTY_ATTRIBUTE_NONE);
  global->SetValue("$atom", atom, V8_PROPERTY_ATTRIBUTE_NONE);
  
  // $native
  CefRefPtr<NativeHandler> nativeHandler = new NativeHandler();    
  global->SetValue("$native", nativeHandler->m_object, V8_PROPERTY_ATTRIBUTE_NONE);
  
  context->Exit();
}

#pragma mark NSWindowDelegate

// Called when the window is about to close. Perform the self-destruction
// sequence by getting rid of the window. By returning YES, we allow the window
// to be removed from the screen.
- (BOOL)windowShouldClose:(id)window {  
  _handler->GetBrowser()->CloseDevTools();  
  
  _appContext = NULL;
  _handler = NULL;
    
  // Clean ourselves up after clearing the stack of anything that might have the window on it.
  [self autorelease];
  
  return YES;
}

@end

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings) {
  CefString(&settings.default_encoding) = "";
  CefString(&settings.user_style_sheet_location) = "";
  
  settings.drag_drop_disabled = false;
  settings.load_drops_disabled = false;
  settings.history_disabled = false;
  settings.remote_fonts_disabled = false;
  settings.encoding_detector_enabled = false;
  settings.javascript_disabled = false;
  settings.javascript_open_windows_disallowed = false;
  settings.javascript_close_windows_disallowed = false;
  settings.javascript_access_clipboard_disallowed = false;
  settings.dom_paste_disabled = false;
  settings.caret_browsing_enabled = false;
  settings.java_disabled = true;
  settings.plugins_disabled = true;
  settings.universal_access_from_file_urls_allowed = true;
  settings.file_access_from_file_urls_allowed = false;
  settings.web_security_disabled = false;
  settings.xss_auditor_enabled = false;
  settings.image_load_disabled = false;
  settings.shrink_standalone_images_to_fit = false;
  settings.site_specific_quirks_disabled = false;
  settings.text_area_resize_disabled = false;
  settings.page_cache_disabled = false;
  settings.tab_to_links_disabled = false;
  settings.hyperlink_auditing_disabled = false;
  settings.user_style_sheet_enabled = false;
  settings.author_and_user_styles_disabled = false;
  settings.local_storage_disabled = false;
  settings.databases_disabled = false;
  settings.application_cache_disabled = false;
  settings.webgl_disabled = false;
  settings.accelerated_compositing_enabled = false;
  settings.threaded_compositing_enabled = false;
  settings.accelerated_layers_disabled = false;
  settings.accelerated_video_disabled = false;
  settings.accelerated_2d_canvas_disabled = false;
  settings.accelerated_drawing_disabled = false;
  settings.accelerated_plugins_disabled = false;
  settings.developer_tools_disabled = false;
}
