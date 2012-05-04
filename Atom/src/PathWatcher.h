#import <Foundation/Foundation.h>

typedef void (^WatchCallback)(NSArray *);

@interface PathWatcher : NSObject {
  int _kq;
  NSMutableDictionary *_fileDescriptorsByPath;
  NSMutableDictionary *_callbacksByFileDescriptor;
}

+ (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback;
+ (void)unwatchPath:(NSString *)path callbackId:(NSString *)callbackId error:(NSError **)error;
+ (void)unwatchAll;

@end
