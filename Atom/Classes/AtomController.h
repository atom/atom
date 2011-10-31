#import <Cocoa/Cocoa.h>

@class JSCocoa;
@class WebView;

@interface AtomController : NSWindowController {
}

@property (retain) WebView *webView;
@property (retain) NSString *path;
@property (retain) JSCocoa *jscocoa;

- (AtomController *)initWithPath:(NSString *)aPath;

@end
