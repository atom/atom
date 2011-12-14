#import <Cocoa/Cocoa.h>

@class JSCocoa;
@class WebView;

@interface AtomController : NSWindowController <NSWindowDelegate> {
}

@property (assign) WebView *webView;
@property (nonatomic, retain) JSCocoa *jscocoa;

@property (nonatomic, retain, readonly) NSString *url;
@property (nonatomic, retain, readonly) NSString *bootstrapScript;

- (id)initForSpecs;
- (id)initWithURL:(NSString *)url;

- (void)createWebView;

@end
