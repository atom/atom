#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSCocoa.h"

@interface FileSystemHelper : NSObject {
  JSContextRef _ctx;
}

- (id)initWithJSContextRef:(JSContextRef)ctx;
- (void)contentsOfDirectoryAtPath:(NSString *)path recursive:(BOOL)recursive onComplete:(JSValueRefAndContextRef)jsFunction;

@end
