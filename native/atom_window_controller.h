#include "include/cef_app.h"

class AtomCefClient;

@interface AtomWindowController : NSWindowController <NSWindowDelegate> {
  NSSplitView *_splitView;
  NSView *_devToolsView;
  NSView *_webView;
  NSButton *_devButton;
  NSString *_bootstrapScript;
  NSString *_resourcePath;
  NSString *_pathToOpen;
  NSNumber *_pidToKillOnClose;

  CefRefPtr<AtomCefClient> _cefClient;
  CefRefPtr<AtomCefClient> _cefDevToolsClient;
  CefRefPtr<CefV8Context> _atomContext;

  BOOL _runningSpecs;
  BOOL _exitWhenDone;
}

@property (nonatomic, retain) IBOutlet NSSplitView *splitView;
@property (nonatomic, retain) IBOutlet NSView *webView;
@property (nonatomic, retain) IBOutlet NSView *devToolsView;
@property (nonatomic, retain) NSString *pathToOpen;

- (id)initWithPath:(NSString *)path;
- (id)initDevWithPath:(NSString *)path;
- (id)initInBackground;
- (id)initSpecsThenExit:(BOOL)exitWhenDone;
- (id)initBenchmarksThenExit:(BOOL)exitWhenDone;
- (void)setPidToKillOnClose:(NSNumber *)pid;

- (void)toggleDevTools;
- (void)showDevTools;

@end
