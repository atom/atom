#import <Foundation/Foundation.h>

typedef void (^WatchCallback)(NSArray *);

@interface PathWatcher : NSObject {
  int _kq;
  NSMutableDictionary *_callbacksByFileDescriptor;
}

+ (void)watchPath:(NSString *)path callback:(WatchCallback)callback;

@end
