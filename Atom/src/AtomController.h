#import <Cocoa/Cocoa.h>

#import "BrowserDelegate.h"
#import "include/cef_base.h"
#import "include/cef_v8.h"

class ClientHandler;

@interface AtomController : NSWindowController <NSWindowDelegate, BrowserDelegate> {
  NSSplitView *_splitView;
  NSView *_webView;
  NSView *_devToolsView;
  NSString *_bootstrapScript;
  NSString *_pathToOpen;
  
  CefRefPtr<CefV8Context> _atomContext;
  CefRefPtr<ClientHandler> _clientHandler;
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript atomContext:(CefRefPtr<CefV8Context>) context;
- (id)initWithPath:(NSString *)path atomContext:(CefRefPtr<CefV8Context>)atomContext;
- (id)initSpecsWithAtomContext:(CefRefPtr<CefV8Context>)atomContext;
- (id)initBenchmarksWithAtomContext:(CefRefPtr<CefV8Context>)atomContext;

- (void)createBrowser;
- (void)showDevTools;
- (void)toggleDevTools;

@property (nonatomic, retain) IBOutlet NSSplitView *splitView;
@property (nonatomic, retain) IBOutlet NSView *webView;
@property (nonatomic, retain) IBOutlet NSView *devToolsView;

@end

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings);
