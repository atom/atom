#include "include/cef_app.h"

class ClientHandler;

@interface AtomController : NSWindowController <NSWindowDelegate> {
  CefRefPtr<ClientHandler> _clientHandler;
	NSView *_webView;
}

@property (nonatomic, retain) IBOutlet NSView *webView;

- (void)populateBrowserSettings:(CefBrowserSettings &)settings;

@end