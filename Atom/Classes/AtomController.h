#import <Cocoa/Cocoa.h>

@class JSCocoa;
@class WebView;

@interface AtomController : NSWindowController {
  IBOutlet WebView *webView;
  NSString *path;
  JSCocoa* jscocoa;
}

@property (retain) IBOutlet WebView *webView;
@property (retain) NSString *path;

- (AtomController *)initWithPath:(NSString *)aPath;
- (BOOL)handleKeyEvent:(NSEvent *)event;

@end
