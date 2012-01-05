#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSCocoa.h"

@interface FileSystemHelper : NSObject {
  JSContextRef _ctx;
}

- (id)initWithJSContextRef:(JSContextRef)ctx;
- (void)listFilesAtPath:(NSString *)path recursive:(BOOL)recursive onComplete:(JSValueRefAndContextRef)jsFunction;
- (BOOL)isFile:(NSString *)path;

@end
