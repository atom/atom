#import <Cocoa/Cocoa.h>
#import "include/cef.h"

class ClientHandler;

@interface AtomController : NSWindowController <NSWindowDelegate> {
  NSView *_webView;
  NSString *_bootstrapScript;
  
  CefRefPtr<CefV8Context> _appContext;
  CefRefPtr<ClientHandler> _handler;
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript appContext:(CefRefPtr<CefV8Context>) context;
- (id)initSpecsWithAppContext:(CefRefPtr<CefV8Context>)appContext;

- (void)createBrowser;

- (void)afterCreated:(CefRefPtr<CefBrowser>) browser;

@property (nonatomic, retain) IBOutlet NSView *webView;

@end

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings);
