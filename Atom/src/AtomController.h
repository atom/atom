#import <Cocoa/Cocoa.h>

#import "BrowserDelegate.h"
#import "include/cef.h"

class ClientHandler;

@interface AtomController : NSWindowController <NSWindowDelegate, BrowserDelegate> {
  NSView *_webView;
  NSString *_bootstrapScript;
  NSString *_pathToOpen;
  
  CefRefPtr<CefV8Context> _atomContext;
  CefRefPtr<ClientHandler> _clientHandler;
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript atomContext:(CefRefPtr<CefV8Context>) context;
- (id)initWithPath:(NSString *)path atomContext:(CefRefPtr<CefV8Context>)atomContext;
- (id)initSpecsWithAtomContext:(CefRefPtr<CefV8Context>)atomContext;

- (void)createBrowser;

@property (nonatomic, retain) IBOutlet NSView *webView;

@end

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings);
