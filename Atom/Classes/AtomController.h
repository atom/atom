#import <Cocoa/Cocoa.h>

@class JSCocoa;
@class WebView;

@interface AtomController : NSWindowController <NSWindowDelegate> {
}

@property (retain) WebView *webView;
@property (retain, readonly) NSString *url;
@property (retain) JSCocoa *jscocoa;

- (AtomController *)initWithURL:(NSString *)url;

@end
