#import "PathWatcher.h"

#import <sys/event.h>
#import <sys/time.h> 
#import <fcntl.h>



@interface PathWatcher ()
- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback;
- (void)watchFileDescriptor:(int)fd;
- (void)unwatchPath:(NSString *)path callbackId:(NSString *)callbackId;
- (void)unwatchAll;
@end

@implementation PathWatcher

+ (id)instance {
  static PathWatcher *pathWatcher;  
  if (!pathWatcher) pathWatcher = [[PathWatcher alloc] init];
  return pathWatcher;
}

+ (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback {
  return [[self instance] watchPath:path callback:callback];
}

+ (void)unwatchPath:(NSString *)path callbackId:(NSString *)callbackId {
  return [[self instance] unwatchPath:path callbackId:callbackId];
}

+ (void)unwatchAll {
  return [[self instance] unwatchAll];
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

- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback {
  path = [path stringByStandardizingPath];
  NSString *callbackId;
  
  @synchronized(self) {
    NSNumber *fdNumber = [_fileDescriptorsByPath objectForKey:path];    
    if (!fdNumber) {
      int fd = open([path fileSystemRepresentation], O_EVTONLY, 0);      
      if (fd < 0) return nil; // TODO: Decide what to do here
      [self watchFileDescriptor:fd];

      fdNumber = [NSNumber numberWithInt:fd];
      [_fileDescriptorsByPath setObject:fdNumber forKey:path];
    }
    
    NSMutableDictionary *callbacks = [_callbacksByFileDescriptor objectForKey:fdNumber];
    if (!callbacks) {      
      callbacks = [NSMutableDictionary dictionary];
      [_callbacksByFileDescriptor setObject:callbacks forKey:fdNumber];      
    }
    
    callbackId = [[NSProcessInfo processInfo] globallyUniqueString];
    [callbacks setObject:callback forKey:callbackId];
  }
  
  return callbackId;
}

- (void)unwatchPath:(NSString *)path callbackId:(NSString *)callbackId {
  @synchronized(self) {
    NSNumber *fdNumber = [_fileDescriptorsByPath objectForKey:path];
    if (!fdNumber) return;    

    NSMutableDictionary *callbacks = [_callbacksByFileDescriptor objectForKey:fdNumber];
    if (!callbacks) return; 
    
    if (callbackId) {
      [callbacks removeObjectForKey:callbackId];
    }
    else {
      [callbacks removeAllObjects];
    }
    
    if (callbacks.count == 0) {
      close([fdNumber intValue]);
      [_fileDescriptorsByPath removeObjectForKey:path];
      [_callbacksByFileDescriptor removeObjectForKey:fdNumber];
    }
  }
}

- (void)unwatchAll {
  @synchronized(self) {
    NSArray *paths = [_fileDescriptorsByPath allKeys];
    for (NSString *path in paths) {
      [self unwatchPath:path callbackId:nil];
    }
  }  
}

- (void)watchFileDescriptor:(int)fd {
  struct timespec timeout = { 0, 0 };
  struct kevent event;
  int filter = EVFILT_VNODE;
  int flags = EV_ADD | EV_ENABLE | EV_CLEAR;
  int filterFlags = NOTE_WRITE;
  EV_SET(&event, fd, filter, flags, filterFlags, 0, 0);
  kevent(_kq, &event, 1, NULL, 0, &timeout);
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
        
        NSDictionary *callbacks = [_callbacksByFileDescriptor objectForKey:fdNumber];
        for (NSString *key in callbacks) {
          WatchCallback callback = [callbacks objectForKey:key];
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
