#import <Cocoa/Cocoa.h>
#import "include/cef.h"

class ClientHandler;

@interface AtomController : NSWindowController <NSWindowDelegate> {
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

- (void)afterCreated;
- (void)loadStart;
- (bool)keyEventOfType:(cef_handler_keyevent_type_t)type code:(int)code modifiers:(int)modifiers isSystemKey:(bool)isSystemKey isAfterJavaScript:(bool)isAfterJavaScript;


@property (nonatomic, retain) IBOutlet NSView *webView;

@end

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings);
