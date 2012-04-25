#import "PathWatcher.h"

#import <sys/event.h>
#import <sys/time.h> 
#import <fcntl.h>

@interface PathWatcher ()
- (void)watchPath:(NSString *)path callback:(WatchCallback)callback;
@end

@implementation PathWatcher

+ (void)watchPath:(NSString *)path callback:(WatchCallback)callback {
  static PathWatcher *pathWatcher;
  
  if (!pathWatcher) pathWatcher = [[PathWatcher alloc] init];
  [pathWatcher watchPath:path callback:callback];
}

- (void)dealloc {
  close(_kq);
  for (NSNumber *fdNumber in [_callbacksByFileDescriptor allKeys]) {
    close([fdNumber intValue]);
  }
  [_callbacksByFileDescriptor release];
}

- (id)init {
  self = [super init];
  
  _callbacksByFileDescriptor = [[NSMutableDictionary alloc] init];
  _kq = kqueue();
  
  if (_kq == -1) {
    [NSException raise:@"Could not create kqueue" format:nil];
  }
  
  [self performSelectorInBackground:@selector(watch) withObject:NULL];
  return self;
}

- (void)watchPath:(NSString *)path callback:(WatchCallback)callback {
  struct timespec timeout = { 0, 0 };
  struct kevent event;
  int fd = open([path fileSystemRepresentation], O_EVTONLY, 0);
  
  if (fd >= 0) {
    int filter = EVFILT_VNODE;
    int flags = EV_ADD | EV_ENABLE | EV_CLEAR;
    int filterFlags = NOTE_ATTRIB | NOTE_WRITE | NOTE_EXTEND | NOTE_RENAME | NOTE_DELETE;
    
    EV_SET(&event, fd, filter, flags, filterFlags, 0, (void *)path);    
    
    @synchronized(self) {
      NSNumber *fdNumber = [NSNumber numberWithInt:fd];
      NSMutableArray *callbacks = [_callbacksByFileDescriptor objectForKey:fdNumber];
      if (!callbacks) {
        callbacks = [NSMutableArray array];
        [_callbacksByFileDescriptor setObject:callbacks forKey:fdNumber];
      }
      [callbacks addObject:callback];
      
      kevent(_kq, &event, 1, NULL, 0, &timeout);
    }
  }
}

- (void)watch {
  @autoreleasepool {
    struct kevent event;    
    struct timespec timeout = { 5, 0 }; // 5 seconds timeout.
    
    while (true) {
      int numberOfEvents = kevent(_kq, NULL, 0, &event, 1, &timeout);
      
      if (numberOfEvents < 0) {
        [NSException raise:@"KQueue Error" format:@"error %d", numberOfEvents, nil];
      }
      if (numberOfEvents == 0) {
        continue;
      }

      NSMutableArray *eventFlags = [NSMutableArray array];

      if (event.fflags & NOTE_WRITE) {
        [eventFlags addObject:@"modified"];
      }
      
      @synchronized(self) {
        NSNumber *fdNumber = [NSNumber numberWithInt:event.ident];
        for (WatchCallback callback in [_callbacksByFileDescriptor objectForKey:fdNumber]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            callback(eventFlags);
          });
        }
      }
    }
    
    [self release];
  }
}

@end
