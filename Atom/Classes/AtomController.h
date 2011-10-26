#import <Cocoa/Cocoa.h>

@class JSCocoa;

@interface AtomController : NSWindowController {
  IBOutlet id webView;
  NSString *URL;
  JSCocoa* jscocoa;
}

@property (assign) IBOutlet id webView;
@property (assign) IBOutlet NSString *URL;

-(BOOL) handleKeyEvent:(NSEvent *)event;

@end
