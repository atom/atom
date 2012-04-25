#import "PathWatcher.h"

#import <sys/event.h>
#import <sys/time.h> 
#import <fcntl.h>

@interface PathWatcher ()
- (void)watchPath:(NSString *)path callback:(WatchCallback)callback;
- (void)watchFileDescriptor:(int)fd;
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
  _fileDescriptorsByPath = [[NSMutableDictionary alloc] init];
  _kq = kqueue();
  
  if (_kq == -1) {
    [NSException raise:@"Could not create kqueue" format:nil];
  }
  
  [self performSelectorInBackground:@selector(watch) withObject:NULL];
  return self;
}

- (void)watchPath:(NSString *)path callback:(WatchCallback)callback {  
  NSLog(@"Watching path %@", path);
  
  path = [path stringByStandardizingPath];
  
  @synchronized(self) {
    NSNumber *fdNumber = [_fileDescriptorsByPath objectForKey:path];    
    if (!fdNumber) {
      int fd = open([path fileSystemRepresentation], O_EVTONLY, 0);      
      if (fd < 0) return; // TODO: Decide what to do here
      [self watchFileDescriptor:fd];

      fdNumber = [NSNumber numberWithInt:fd];
      [_fileDescriptorsByPath setObject:fdNumber forKey:path];
    }
    
    NSMutableArray *callbacks = [_callbacksByFileDescriptor objectForKey:fdNumber];
    if (!callbacks) {      
      callbacks = [NSMutableArray array];
      [_callbacksByFileDescriptor setObject:callbacks forKey:fdNumber];      
    }
    
    [callbacks addObject:callback];
  }
}

- (void)watchFileDescriptor:(int)fd {
  NSLog(@"Watching fd %d", fd);
  
  struct timespec timeout = { 0, 0 };
  struct kevent event;
  int filter = EVFILT_VNODE;
  int flags = EV_ADD | EV_ENABLE | EV_CLEAR;
  int filterFlags = NOTE_WRITE;
  EV_SET(&event, fd, filter, flags, filterFlags, 0, 0);
  kevent(_kq, &event, 1, NULL, 0, &timeout);
}

- (void)watch {  
  NSLog(@"kicking off watch");
  
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

      NSLog(@"flags are: %d, fd is: %d", event.fflags, (int)event.ident);
      
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
