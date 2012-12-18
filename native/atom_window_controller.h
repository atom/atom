#include "include/cef_app.h"

class AtomCefClient;

@interface AtomWindowController : NSWindowController <NSWindowDelegate> {
  NSSplitView *_splitView;
  NSView *_devToolsView;
  NSView *_webView;
  NSString *_bootstrapScript;
  NSString *_resourcePath;
  NSString *_pathToOpen;

  CefRefPtr<AtomCefClient> _cefClient;
  CefRefPtr<AtomCefClient> _cefDevToolsClient;
  CefRefPtr<CefV8Context> _atomContext;

  BOOL _runningSpecs;
  BOOL _exitWhenDone;
}

@property (nonatomic, retain) IBOutlet NSSplitView *splitView;
@property (nonatomic, retain) IBOutlet NSView *webView;
@property (nonatomic, retain) IBOutlet NSView *devToolsView;

- (id)initWithPath:(NSString *)path;
- (id)initUnstableWithPath:(NSString *)path;
- (id)initInBackground;
- (id)initSpecsThenExit:(BOOL)exitWhenDone;
- (id)initBenchmarksThenExit:(BOOL)exitWhenDone;
- (id)initWithBootstrapScript:(NSString *)bootstrapScript background:(BOOL)background alwaysUseBundleResourcePath:(BOOL)alwaysUseBundleResourcePath;

- (void)toggleDevTools;
- (void)showDevTools;

@end
