#include "include/cef_app.h"

class ClientHandler;

@interface AtomController : NSWindowController <NSWindowDelegate> {
	NSView *_webView;
	NSString *_bootstrapScript;
	NSString *_pathToOpen;

	CefRefPtr<ClientHandler> _clientHandler;
	CefRefPtr<CefV8Context> _atomContext;

	bool _runningSpecs;
}

@property (nonatomic, retain) IBOutlet NSView *webView;

- (id)initWithPath:(NSString *)path;
- (id)initSpecs;
- (id)initBenchmarks;

@end