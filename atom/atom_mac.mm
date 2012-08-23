#import "include/cef_application_mac.h"
#import "atom/client_handler.h"
#import "atom/atom_mac.h"
#import "atom/atom_controller.h"

@implementation Atom

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
  
  settings.remote_debugging_port = 9090;
  settings.log_severity = LOGSEVERITY_ERROR;
}


- (void)dealloc {
  [_hiddenWindow release];
  [super dealloc];
}

- (void)createAtomContext {
  _clientHandler = new ClientHandler();
  
  CefWindowInfo window_info;
  _hiddenWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 0, 0) styleMask:nil backing:nil defer:YES];
  window_info.SetAsChild([_hiddenWindow contentView], 0, 0, 0, 0);
  
  CefBrowserSettings settings;
  NSURL *resourceDirURL = [[NSBundle mainBundle] resourceURL];
  NSString *indexURLString = [[resourceDirURL URLByAppendingPathComponent:@"index.html"] absoluteString];
	CefBrowserHost::CreateBrowser(window_info, _clientHandler.get(), [indexURLString UTF8String], settings);
}

- (void)open:(NSString *)path {
  [[AtomController alloc] initWithPath:path atomContext:NULL];
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

#pragma mark BrowserDelegate

- (void)loadStart {
  [self modifyJavaScript:^(CefRefPtr<CefV8Context> context, CefRefPtr<CefV8Value> global) {
    CefRefPtr<CefV8Value> bootstrapScript = CefV8Value::CreateString("atom-bootstrap");
    global->SetValue("$bootstrapScript", bootstrapScript, V8_PROPERTY_ATTRIBUTE_NONE);
		
    CefRefPtr<CefV8Value> atom = CefV8Value::CreateObject(NULL);
    global->SetValue("atom", atom, V8_PROPERTY_ATTRIBUTE_NONE);
		
    
#ifdef LOAD_RESOURCES_FROM_DIR
    char path[] = LOAD_RESOURCES_FROM_DIR;
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


# pragma mark NSApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
//  new NativeHandler();
//  new OnigRegexpExtension();
  
  [self createAtomContext];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  CefShutdown();
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
  if ([[self mainMenu] performKeyEquivalent:event]) return;
  
  if (_clientHandler && ![self keyWindow] && [event type] == NSKeyDown) {
    [_hiddenWindow makeKeyAndOrderFront:self];
    [_hiddenWindow sendEvent:event];
  }
  else {
    [super sendEvent:event];
  }
}

@end