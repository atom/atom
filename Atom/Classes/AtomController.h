#import <Cocoa/Cocoa.h>

@class JSCocoa;
@class WebView;

@interface AtomController : NSWindowController <NSWindowDelegate> {
}

@property (retain) WebView *webView;
@property (nonatomic, retain) JSCocoa *jscocoa;

@property (nonatomic, retain, readonly) NSString *url;
@property (nonatomic, retain, readonly) NSString *bootstrapPage;

- (id)initForSpecs;
- (AtomController *)initWithURL:(NSString *)url;

@end
