#import "FileSystemHelper.h"

@interface FileSystemHelper ()
- (NSArray *)listFilesAtPath:(NSString *)path recursive:(BOOL)recursive;
- (JSValueRef)convertToJSArrayOfStrings:(NSArray *)nsArray;
@end

@implementation FileSystemHelper

- (id)initWithJSContextRef:(JSContextRef)ctx {
  self = [super init];
  _ctx = ctx;
  return self;
}

- (void)listFilesAtPath:(NSString *)path recursive:(BOOL)recursive onComplete:(JSValueRefAndContextRef)onComplete {
  dispatch_queue_t backgroundQueue = dispatch_get_global_queue(0, 0);
  dispatch_queue_t mainQueue = dispatch_get_main_queue();
  
  JSValueRef onCompleteFn = onComplete.value;
  
  JSValueProtect(_ctx, onCompleteFn);
  
  dispatch_async(backgroundQueue, ^{
    NSArray *paths = [self listFilesAtPath:path recursive:recursive];
    JSValueRef jsPaths = [self convertToJSArrayOfStrings:paths];
    
    dispatch_sync(mainQueue, ^{
      JSValueRef args[] = { jsPaths };
      JSObjectCallAsFunction(_ctx, JSValueToObject(_ctx, onCompleteFn, NULL), NULL, 1, args, NULL);
      JSValueUnprotect(_ctx, onCompleteFn);
    });
  });
}

- (BOOL)isFile:(NSString *)path {
  BOOL isDir, exists;
  exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
  return exists && !isDir;
}

- (NSArray *)listFilesAtPath:(NSString *)path recursive:(BOOL)recursive {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableArray *paths = [NSMutableArray array];
  
  if (recursive) {    
    for (NSString *subpath in [fm enumeratorAtPath:path]) {
      [paths addObject:[path stringByAppendingPathComponent:subpath]];
    }
  } else {
    NSError *error = nil;          
    NSArray *subpaths = [fm contentsOfDirectoryAtPath:path error:&error];      
    if (error) {
      NSLog(@"ERROR %@", error.localizedDescription);      
      return nil;
    }
    for (NSString *subpath in subpaths) {
      [paths addObject:[path stringByAppendingPathComponent:subpath]];
    }
  }
  
  NSMutableArray *filePaths = [NSMutableArray array];  
  for (NSString *path in paths) {
    if ([self isFile:path]) [filePaths addObject:path];
  }  
  return filePaths;
}

- (JSValueRef)convertToJSArrayOfStrings:(NSArray *)nsArray {
  JSValueRef *cArray = malloc(sizeof(JSValueRef) * nsArray.count);
  for (int i = 0; i < nsArray.count; i++) {    
    JSStringRef jsString = JSStringCreateWithCFString((CFStringRef)[nsArray objectAtIndex:i]);    
    cArray[i] = JSValueMakeString(_ctx, jsString);
    JSStringRelease(jsString);
  }
  JSValueRef jsArray = (JSValueRef)JSObjectMakeArray(_ctx, nsArray.count, cArray, NULL);                            
  free(cArray);
  return jsArray;
}

@end
