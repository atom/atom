#import "Atom.h"
#import "include/cef_base.h"
#import "AtomController.h"

#import "native_handler.h"
#import "client_handler.h"
#import "include/cef_app.h"

@interface Atom ()
- (CefRefPtr<CefV8Context>)atomContext;
@end

// Provide the CefAppProtocol implementation required by CEF.
@implementation Atom

+ (id)sharedApplication {
  id atomApp = [super sharedApplication];
  
  CefSettings settings;
  AppGetSettings(settings);
  
  CefRefPtr<CefApp> app;
  CefInitialize(settings, app);
  
  return atomApp;
}

- (void)dealloc {
  [_hiddenWindow release];
  [super dealloc];
}

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent sendingEventScoper;

  if ([[self mainMenu] performKeyEquivalent:event]) return;
  
  if (_clientHandler && ![self keyWindow] && [event type] == NSKeyDown) {
    [_hiddenWindow makeKeyAndOrderFront:self];
    [_hiddenWindow sendEvent:event];
  }
  else {
    [super sendEvent:event];
  }
}

- (void)createAtomContext {
  _clientHandler = new ClientHandler(self);
  
  CefWindowInfo window_info;
  _hiddenWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 0, 0) styleMask:nil backing:nil defer:YES];
  window_info.SetAsChild([_hiddenWindow contentView], 0, 0, 0, 0);
  
  CefBrowserSettings settings;  
  NSURL *resourceDirURL = [[NSBundle mainBundle] resourceURL];
  NSString *indexURLString = [[resourceDirURL URLByAppendingPathComponent:@"index.html"] absoluteString];
  CefBrowser::CreateBrowser(window_info, _clientHandler.get(), [indexURLString UTF8String], settings);
}

- (void)open:(NSString *)path {
  [[AtomController alloc] initWithPath:path atomContext:[self atomContext]];
}

- (IBAction)runSpecs:(id)sender {
  [[AtomController alloc] initSpecsWithAtomContext:[self atomContext]];
}

- (IBAction)runBenchmarks:(id)sender {
  [[AtomController alloc] initBenchmarksWithAtomContext:[self atomContext]];
}

- (void)modifyJavaScript:(void(^)(CefRefPtr<CefV8Context>, CefRefPtr<CefV8Value>))callback {
  CefRefPtr<CefV8Context> context = _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
  CefRefPtr<CefV8Value> global = context->GetGlobal();
  
  context->Enter();
  
  callback(context, global);
  
  context->Exit();
}

- (CefRefPtr<CefV8Context>)atomContext {
  return _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  [self createAtomContext];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  CefShutdown();
}

#pragma mark BrowserDelegate

- (void)loadStart {
  [self modifyJavaScript:^(CefRefPtr<CefV8Context> context, CefRefPtr<CefV8Value> global) {
    CefRefPtr<CefV8Value> bootstrapScript = CefV8Value::CreateString("atom-bootstrap");
    global->SetValue("$bootstrapScript", bootstrapScript, V8_PROPERTY_ATTRIBUTE_NONE);

    CefRefPtr<NativeHandler> nativeHandler = new NativeHandler();
    global->SetValue("$native", nativeHandler->m_object, V8_PROPERTY_ATTRIBUTE_NONE);

    CefRefPtr<CefV8Value> atom = CefV8Value::CreateObject(NULL, NULL);
    global->SetValue("atom", atom, V8_PROPERTY_ATTRIBUTE_NONE);

#define STR_VALUE(arg) #arg
#if defined(LOAD_RESOURCES_FROM_DIR)
    char path[] = STR_VALUE(LOAD_RESOURCES_FROM_DIR);
#else
    const char *path = [[[NSBundle mainBundle] resourcePath] UTF8String];
#endif
    
    CefRefPtr<CefV8Value> loadPath = CefV8Value::CreateString(path);
    atom->SetValue("loadPath", loadPath, V8_PROPERTY_ATTRIBUTE_NONE);    
  }];
}

- (void)loadEnd {
  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--headless"]) {
    [self modifyJavaScript:^(CefRefPtr<CefV8Context> context, CefRefPtr<CefV8Value> global) {
      CefRefPtr<CefV8Value> atom = context->GetGlobal()->GetValue("atom");    
      atom->SetValue("headless", CefV8Value::CreateBool(YES), V8_PROPERTY_ATTRIBUTE_NONE);
    }]; 
  }
  
  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--benchmark"]) {
    [self runBenchmarks:self];
  }
  
  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--test"]) {
    [self runSpecs:self];
  }
}

@end
  
// Returns the application settings based on command line arguments.
void AppGetSettings(CefSettings& settings) {  
  CefString(&settings.cache_path) = "";
  CefString(&settings.user_agent) = "";
  CefString(&settings.product_version) = "";
  CefString(&settings.locale) = "";
  CefString(&settings.log_file) = "";
  CefString(&settings.javascript_flags) = "";
  
  settings.log_severity = LOGSEVERITY_ERROR;
  settings.local_storage_quota = 0;
  settings.session_storage_quota = 0;
}
