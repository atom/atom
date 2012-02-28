#import <Cocoa/Cocoa.h>
#import "include/cef.h"

@interface AtomController : NSWindowController <NSWindowDelegate> {
  NSView *_webView;
  NSString *_bootstrapScript;
}

- (id)initWithBootstrapScript:(NSString *)bootstrapScript;
- (id)initForSpecs;

- (void)afterCreated:(CefRefPtr<CefBrowser>) browser;

@property (nonatomic, retain) IBOutlet NSView *webView;

@end

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings);
