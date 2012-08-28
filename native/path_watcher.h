#import "include/cef_base.h"
#import "include/cef_v8.h"
#import <Foundation/Foundation.h>

typedef void (^WatchCallback)(NSString *, NSString *);

@interface PathWatcher : NSObject {
  int _kq;
  CefRefPtr<CefV8Context> _context;
  NSMutableDictionary *_fileDescriptorsByPath;
  NSMutableDictionary *_callbacksByFileDescriptor;

  bool _keepWatching;
}

+ (PathWatcher *)pathWatcherForContext:(CefRefPtr<CefV8Context>)context;
+ (void)removePathWatcherForContext:(CefRefPtr<CefV8Context>)context;

- (id)initWithContext:(CefRefPtr<CefV8Context>)context;
- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback;
- (void)unwatchPath:(NSString *)path callbackId:(NSString *)callbackId error:(NSError **)error;


@end
