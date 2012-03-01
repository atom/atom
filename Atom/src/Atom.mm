#import "Atom.h"
#import "include/cef.h"
#import "AtomController.h"

#import "native_handler.h"
#import "client_handler.h"

// Provide the CefAppProtocol implementation required by CEF.
@implementation Atom

+ (NSApplication *)sharedApplication {
  if (!NSApp) {
    // Populate the settings based on command line arguments.
    CefSettings settings;
    AppGetSettings(settings);
    
    // Initialize CEF.
    CefRefPtr<CefApp> app;
    CefInitialize(settings, app);
  }
  
  return [super sharedApplication];  
}

- (void)dealloc {
  [_hiddenGlobalView release];
  [self dealloc];
}

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

- (void)createAtomContext {
  _clientHandler = new ClientHandler(self);
  
  CefWindowInfo window_info;
  _hiddenGlobalView = [[NSView alloc] init];
  window_info.SetAsChild(_hiddenGlobalView, 0, 0, 0, 0);

  CefBrowserSettings settings;  
  NSURL *resourceDirURL = [[NSBundle mainBundle] resourceURL];
  NSString *indexURLString = [[resourceDirURL URLByAppendingPathComponent:@"index.html"] absoluteString];
  CefBrowser::CreateBrowser(window_info, _clientHandler.get(), [indexURLString UTF8String], settings);
}

- (void)open:(NSString *)path {
  CefRefPtr<CefV8Context> atomContext = _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
  [[AtomController alloc] initWithPath:path atomContext:atomContext];
}

- (IBAction)runSpecs:(id)sender {
  CefRefPtr<CefV8Context> atomContext = _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
  [[AtomController alloc] initSpecsWithAtomContext:atomContext];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  [self createAtomContext];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  CefShutdown();
}

- (void)afterCreated {
  _clientHandler->GetBrowser()->ShowDevTools();
}

- (void)loadStart {
  CefRefPtr<CefV8Context> context = _clientHandler->GetBrowser()->GetMainFrame()->GetV8Context();
  CefRefPtr<CefV8Value> global = context->GetGlobal();

  context->Enter();

  CefRefPtr<CefV8Value> bootstrapScript = CefV8Value::CreateString("atom-bootstrap");
  global->SetValue("$bootstrapScript", bootstrapScript, V8_PROPERTY_ATTRIBUTE_NONE);
  
  CefRefPtr<CefV8Value> atom = CefV8Value::CreateObject(NULL);
  global->SetValue("atom", atom, V8_PROPERTY_ATTRIBUTE_NONE);
  
  CefRefPtr<NativeHandler> nativeHandler = new NativeHandler();
  atom->SetValue("native", nativeHandler->m_object, V8_PROPERTY_ATTRIBUTE_NONE);
  
  CefRefPtr<CefV8Value> loadPath = CefV8Value::CreateString(PROJECT_DIR);
  atom->SetValue("loadPath", loadPath, V8_PROPERTY_ATTRIBUTE_NONE);
  
  context->Exit();
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
