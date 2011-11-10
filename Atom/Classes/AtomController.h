#import <Cocoa/Cocoa.h>

@class JSCocoa;
@class WebView;

@interface AtomController : NSWindowController <NSWindowDelegate> {
}

@property (retain) WebView *webView;
@property (retain, readonly) NSString *path;
@property (retain) JSCocoa *jscocoa;

- (AtomController *)initWithPath:(NSString *)aPath;

@end
