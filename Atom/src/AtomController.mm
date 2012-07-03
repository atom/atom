#import "AtomController.h"

#import "include/cef_base.h"
#import "client_handler.h"
#import "PathWatcher.h"

@implementation AtomController

@synthesize splitView=_splitView;
@synthesize webView=_webView;
@synthesize devToolsView=_devToolsView;

- (void)dealloc {
  [_bootstrapScript release];
  [_splitView release];
  [_webView release];
  [_devToolsView release];
  [_pathToOpen release];

  [super dealloc];
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript atomContext:(CefRefPtr<CefV8Context>)atomContext {
  self = [super initWithWindowNibName:@"ClientWindow"];
  _bootstrapScript = [bootstrapScript retain];
  _atomContext = atomContext;

  [self.window makeKeyAndOrderFront:nil];
  [self createBrowser];
    
  return self;
}

- (id)initWithPath:(NSString *)path atomContext:(CefRefPtr<CefV8Context>)atomContext {
  _pathToOpen = [path retain];
  return [self initWithBootstrapScript:@"window-bootstrap" atomContext:atomContext];
}

- (id)initSpecsWithAtomContext:(CefRefPtr<CefV8Context>)atomContext {
  _runningSpecs = true;
  return [self initWithBootstrapScript:@"spec-bootstrap" atomContext:atomContext];
}

- (id)initBenchmarksWithAtomContext:(CefRefPtr<CefV8Context>)atomContext {
  return [self initWithBootstrapScript:@"benchmark-bootstrap" atomContext:atomContext];
}

- (void)windowDidLoad {
  [self.window setDelegate:self];  
  [self.window setReleasedWhenClosed:NO];
}

- (void)createBrowser {  
  _clientHandler = new ClientHandler(self);
  
  CefWindowInfo window_info;
  CefBrowserSettings settings;
  
  AppGetBrowserSettings(settings);
  
  window_info.SetAsChild(self.webView, 0, 0, self.webView.bounds.size.width, self.webView.bounds.size.height);
  
  NSURL *resourceDirURL = [[NSBundle mainBundle] resourceURL];
  NSString *indexURLString = [[resourceDirURL URLByAppendingPathComponent:@"index.html"] absoluteString];
  CefBrowser::CreateBrowser(window_info, _clientHandler.get(), [indexURLString UTF8String], settings);  
}

- (void)showDevTools {
  if (!_devToolsView) {
    [self toggleDevTools];
  }
}

- (void)toggleDevTools {
  if (_devToolsView) {
    [_devToolsView removeFromSuperview];
    [_devToolsView release];
    _devToolsView = nil;
  }
  else if (_clientHandler && _clientHandler->GetBrowser()) {
    NSRect frame = NSMakeRect(0, 0, _splitView.frame.size.height, _splitView.frame.size.height);
    _devToolsView = [[NSView alloc] initWithFrame:frame];
    [_splitView addSubview:_devToolsView];
    _clientHandler->GetBrowser()->ShowDevTools();
  }
  
  [_splitView adjustSubviews];
}

#pragma mark BrowserDelegate
- (void)loadStart {
  CefRefPtr<CefV8Context> context = _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
  CefRefPtr<CefV8Value> global = context->GetGlobal();
  
  context->Enter();

  CefRefPtr<CefV8Value> windowNumber = CefV8Value::CreateInt(self.window.windowNumber);
  global->SetValue("$windowNumber", windowNumber, V8_PROPERTY_ATTRIBUTE_NONE);
  
  CefRefPtr<CefV8Value> bootstrapScript = CefV8Value::CreateString([_bootstrapScript UTF8String]);
  global->SetValue("$bootstrapScript", bootstrapScript, V8_PROPERTY_ATTRIBUTE_NONE);
  
  CefRefPtr<CefV8Value> pathToOpen = _pathToOpen ? CefV8Value::CreateString([_pathToOpen UTF8String]) : CefV8Value::CreateNull();
  global->SetValue("$pathToOpen", pathToOpen, V8_PROPERTY_ATTRIBUTE_NONE);
    
  global->SetValue("atom", _atomContext->GetGlobal()->GetValue("atom"), V8_PROPERTY_ATTRIBUTE_NONE);
  
  context->Exit();
}

- (bool)keyEventOfType:(cef_handler_keyevent_type_t)type code:(int)code modifiers:(int)modifiers isSystemKey:(bool)isSystemKey isAfterJavaScript:(bool)isAfterJavaScript {  
  if (isAfterJavaScript && type == KEYEVENT_RAWKEYDOWN && modifiers == KEY_META && code == 'R') {
    
    CefRefPtr<CefV8Context> context = _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
    CefRefPtr<CefV8Value> global = context->GetGlobal();
    
    context->Enter();
    CefRefPtr<CefV8Value> retval;
    CefRefPtr<CefV8Exception> exception;
    CefV8ValueList arguments;
    global->GetValue("reload")->ExecuteFunction(global, arguments, retval, exception, true);
    if (exception) _clientHandler->GetBrowser()->ReloadIgnoreCache();
    context->Exit();
    

    return YES;
  }
  
  return NO;
}

#pragma mark NSWindowDelegate
- (void)windowDidResignMain:(NSNotification *)notification {
  if (_clientHandler && _clientHandler->GetBrowser() && !_runningSpecs) {
    _clientHandler->GetBrowser()->SendFocusEvent(false);
  }
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
  if (_clientHandler && _clientHandler->GetBrowser()) {
    _clientHandler->GetBrowser()->SendFocusEvent(true);
  }
}

- (BOOL)windowShouldClose:(id)window {
  CefRefPtr<CefV8Context> context = _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
  CefRefPtr<CefV8Value> global = context->GetGlobal();
  
  context->Enter();
  
  CefRefPtr<CefV8Value> atom = context->GetGlobal()->GetValue("atom");

  CefRefPtr<CefV8Value> retval;
  CefRefPtr<CefV8Exception> exception;
  CefV8ValueList arguments;
  arguments.push_back(global);
  
  atom->GetValue("windowClosed")->ExecuteFunction(atom, arguments, retval, exception, true);
  
  context->Exit();
  
  _clientHandler->GetBrowser()->CloseDevTools();
  
  _atomContext = NULL;
  _clientHandler = NULL;  
    
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
  settings.web_security_disabled = true;
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
  settings.accelerated_plugins_disabled = false;
  settings.developer_tools_disabled = false;
}
