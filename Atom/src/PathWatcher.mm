#import "PathWatcher.h"

#import <sys/event.h>
#import <sys/time.h> 
#import <sys/param.h> 
#import <fcntl.h>

static NSMutableArray *gPathWatchers;

@interface PathWatcher ()
- (bool)usesContext:(CefRefPtr<CefV8Context>)context;
- (void)watchFileDescriptor:(int)fd;
- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback callbackId:(NSString *)callbackId;
- (void)stopWatching;
- (void)reassignFileDescriptor:(NSNumber *)fdNumber from:(NSString *)path to:(NSString *)newPath;
- (bool)isAtomicWrite:(struct kevent)event;
@end

@implementation PathWatcher

+ (PathWatcher *)pathWatcherForContext:(CefRefPtr<CefV8Context>)context {
  if (!gPathWatchers) gPathWatchers = [[NSMutableArray alloc] init];

  PathWatcher *pathWatcher = nil;
  for (PathWatcher *p in gPathWatchers) {
    if ([p usesContext:context]) {
      pathWatcher = p;
      break;
    }
  }
  
  if (!pathWatcher) {
    pathWatcher = [[[PathWatcher alloc] initWithContext:context] autorelease];
    [gPathWatchers addObject:pathWatcher];
  }
  
  return pathWatcher;
}

+ (void)removePathWatcherForContext:(CefRefPtr<CefV8Context>)context {
  PathWatcher *pathWatcher = nil;
  for (PathWatcher *p in gPathWatchers) {
    if ([p usesContext:context]) {
      pathWatcher = p;
      break;
    }
  }
  
  if (pathWatcher) {
    [pathWatcher stopWatching];
    [gPathWatchers removeObject:pathWatcher];
  }

}

- (void)dealloc {
  close(_kq);
  for (NSNumber *fdNumber in [_callbacksByFileDescriptor allKeys]) {
    close([fdNumber intValue]);
  }
  [_callbacksByFileDescriptor release];
  _context = nil;
  [super dealloc];
}

- (id)initWithContext:(CefRefPtr<CefV8Context>)context {
  self = [super init];
  
  _keepWatching = YES;
  _callbacksByFileDescriptor = [[NSMutableDictionary alloc] init];
  _fileDescriptorsByPath = [[NSMutableDictionary alloc] init];
  _kq = kqueue();
  _context = context;
  
  if (_kq == -1) {
    [NSException raise:@"PathWatcher" format:@"Could not create kqueue"];
  }
  
  [self performSelectorInBackground:@selector(watch) withObject:NULL];
  return self;
}

- (bool)usesContext:(CefRefPtr<CefV8Context>)context {
  return _context->IsSame(context);
}

- (void)stopWatching {
  [self unwatchAll];
  _keepWatching = false;
}

- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback {
  NSString *callbackId = [[NSProcessInfo processInfo] globallyUniqueString];
  return [self watchPath:path callback:callback callbackId:callbackId];
}

- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback callbackId:(NSString *)callbackId {
  path = [path stringByStandardizingPath];
  
  @synchronized(self) {
    NSNumber *fdNumber = [_fileDescriptorsByPath objectForKey:path];    
    if (!fdNumber) {
      int fd = open([path fileSystemRepresentation], O_EVTONLY, 0);      
      if (fd < 0) return nil;
      [self watchFileDescriptor:fd];
      
      fdNumber = [NSNumber numberWithInt:fd];
      [_fileDescriptorsByPath setObject:fdNumber forKey:path];
    }
    
    NSMutableDictionary *callbacks = [_callbacksByFileDescriptor objectForKey:fdNumber];
    if (!callbacks) {      
      callbacks = [NSMutableDictionary dictionary];
      [_callbacksByFileDescriptor setObject:callbacks forKey:fdNumber];      
    }
    
    [callbacks setObject:callback forKey:callbackId];
  }
  
  return callbackId;
}

- (void)unwatchPath:(NSString *)path callbackId:(NSString *)callbackId error:(NSError **)error {
  path = [path stringByStandardizingPath];

  @synchronized(self) {
    NSNumber *fdNumber = [_fileDescriptorsByPath objectForKey:path];
    if (!fdNumber) {
      NSString *message = [NSString stringWithFormat:@"Trying to unwatch %@, which we aren't watching", path];
      NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
      if (error) {
        NSError *e = [NSError errorWithDomain:@"PathWatcher" code:0 userInfo:userInfo];
        *error = e;
      }
      return;    
    }

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
      [_callbacksByFileDescriptor removeObjectForKey:fdNumber];      
      [_fileDescriptorsByPath removeObjectForKey:path];
    }
  }
}

- (void)unwatchAll {
  @synchronized(self) {
    NSArray *paths = [_fileDescriptorsByPath allKeys];
    for (NSString *path in paths) {
      [self unwatchPath:path callbackId:nil error:nil];
    }
  }  
}

- (void)watchFileDescriptor:(int)fd {
  struct timespec timeout = { 0, 0 };
  struct kevent event;
  int filter = EVFILT_VNODE;
  int flags = EV_ADD | EV_ENABLE | EV_CLEAR;
  int filterFlags = NOTE_WRITE | NOTE_DELETE | NOTE_RENAME;
  EV_SET(&event, fd, filter, flags, filterFlags, 0, 0);
  kevent(_kq, &event, 1, NULL, 0, &timeout);
}

- (NSString *)pathForFileDescriptor:(NSNumber *)fdNumber {
  @synchronized(self) {
    for (NSString *path in _fileDescriptorsByPath) {
      if ([[_fileDescriptorsByPath objectForKey:path] isEqual:fdNumber]) {
        return path;
      }
    }
  }
  
  return nil;
}

- (bool)isAtomicWrite:(struct kevent)event {
  if (!event.fflags & NOTE_DELETE) return NO;
  
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = nil;
  @synchronized(self) {
    for (path in [_fileDescriptorsByPath allKeys]) {
      if ([[_fileDescriptorsByPath objectForKey:path] unsignedLongValue] == event.ident) {
        return [fm fileExistsAtPath:path];
      }
    }
  }
  
  return NO;
}

- (void)reassignFileDescriptor:(NSNumber *)fdNumber from:(NSString *)path to:(NSString *)newPath {
  @synchronized(self) {
    bool notWatchingFd = [_fileDescriptorsByPath valueForKey:path] == nil;
    if (notWatchingFd) return;

    [_fileDescriptorsByPath removeObjectForKey:path];
    [_fileDescriptorsByPath setObject:fdNumber forKey:newPath];
  }
}

- (void)updatePath:(NSString *)path forFileDescriptor:(NSNumber *)fdNumber {
  // The path associated with the fd been updated. Remove references to old fd 
  // and make sure the path and callbacks are linked with new fd.
  @synchronized(self) {
    NSDictionary *callbacks = [NSDictionary dictionaryWithDictionary:[_callbacksByFileDescriptor objectForKey:fdNumber]];          
    [self unwatchPath:path callbackId:nil error:nil];
    for (NSString *callbackId in [callbacks allKeys]) {
      [self watchPath:path callback:[callbacks objectForKey:callbackId] callbackId:callbackId];
    }  
  }
}

- (void)watch {  
  struct kevent event;    
  struct timespec timeout = { 5, 0 }; // 5 seconds timeout.
  
  while (_keepWatching) {
    @autoreleasepool {
      int numberOfEvents = kevent(_kq, NULL, 0, &event, 1, &timeout);
      
      if (numberOfEvents < 0) {
        NSLog(@"PathWatcher: error %d", numberOfEvents);
      }
      if (numberOfEvents == 0) {
        continue;
      }

      NSNumber *fdNumber = [NSNumber numberWithInt:event.ident];
      NSString *eventFlag = nil;
      NSString *path = [[[self pathForFileDescriptor:fdNumber] retain] autorelease];
      NSString *newPath = nil;
      
      if (event.fflags & NOTE_WRITE) {
        eventFlag = @"contents-change";
      }
      else if ([self isAtomicWrite:event]) {        
        eventFlag = @"contents-change";
        [self updatePath:path forFileDescriptor:fdNumber];
      }
      else if (event.fflags & NOTE_DELETE) {
        close((int)event.ident);
        int checkFd = open([path fileSystemRepresentation], O_EVTONLY, 0 );
        
        printf("remove %X %d %s\n", event.fflags, checkFd, [path UTF8String]);
        
        eventFlag = @"remove";
      }
      else if (event.fflags & NOTE_RENAME) {
        eventFlag = @"move";
        char pathBuffer[MAXPATHLEN];
        fcntl((int)event.ident, F_GETPATH, &pathBuffer);
        newPath = [NSString stringWithUTF8String:pathBuffer];
      }
            
      NSDictionary *callbacks;
      @synchronized(self) {
        callbacks = [NSDictionary dictionaryWithDictionary:[_callbacksByFileDescriptor objectForKey:fdNumber]];
      }

      dispatch_sync(dispatch_get_main_queue(), ^{
        for (NSString *key in callbacks) {
          WatchCallback callback = [callbacks objectForKey:key];                        
          callback(eventFlag, newPath ? newPath : path);
        }
      });

      if (event.fflags & NOTE_RENAME) {
        [self reassignFileDescriptor:fdNumber from:path to:newPath];
      }
    }
  }
}

@end
