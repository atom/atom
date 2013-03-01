#import <sys/event.h>
#import <sys/time.h>
#import <sys/param.h>
#import <fcntl.h>

#import "path_watcher.h"

static NSMutableArray *gPathWatchers;

@interface PathWatcher ()
- (bool)usesContext:(CefRefPtr<CefV8Context>)context;
- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback callbackId:(NSString *)callbackId;
- (void)stopWatching;
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
  @synchronized(self) {
    close(_kq);
    for (NSString *path in [_callbacksByPath allKeys]) {
      [self removeKeventForPath:path];
    }
    [_callbacksByPath release];
    _context = nil;
    _keepWatching = false;
  }

  [super dealloc];
}

- (id)initWithContext:(CefRefPtr<CefV8Context>)context {
  self = [super init];

  _keepWatching = YES;
  _callbacksByPath = [[NSMutableDictionary alloc] init];
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
  @synchronized(self) {
    [self unwatchAllPaths];
    _keepWatching = false;
  }
}

- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback {
  NSString *callbackId = [[NSProcessInfo processInfo] globallyUniqueString];
  return [self watchPath:path callback:callback callbackId:callbackId];
}

- (NSString *)watchPath:(NSString *)path callback:(WatchCallback)callback callbackId:(NSString *)callbackId {
  path = [path stringByStandardizingPath];
  @synchronized(self) {
    if (![self createKeventForPath:path]) {
      NSLog(@"WARNING: Failed to create kevent for path '%@'", path);
      return nil;
    }

    NSMutableDictionary *callbacks = [_callbacksByPath objectForKey:path];
    if (!callbacks) {
      callbacks = [NSMutableDictionary dictionary];
      [_callbacksByPath setObject:callbacks forKey:path];
    }

    [callbacks setObject:callback forKey:callbackId];
  }

  return callbackId;
}

- (void)unwatchPath:(NSString *)path callbackId:(NSString *)callbackId error:(NSError **)error {
  path = [path stringByStandardizingPath];

  @synchronized(self) {
    NSMutableDictionary *callbacks = [_callbacksByPath objectForKey:path];

    if (callbacks) {
      if (callbackId) {
        [callbacks removeObjectForKey:callbackId];
      }
      else {
        [callbacks removeAllObjects];
      }

      if (callbacks.count == 0) {
        [self removeKeventForPath:path];
        [_callbacksByPath removeObjectForKey:path];
      }
    }
  }
}

- (NSArray *)watchedPaths {
  return [_callbacksByPath allKeys];
}

- (void)unwatchAllPaths {
  @synchronized(self) {
    NSArray *paths = [_callbacksByPath allKeys];
    for (NSString *path in paths) {
      [self unwatchPath:path callbackId:nil error:nil];
    }
  }
}

- (bool)createKeventForPath:(NSString *)path {
  path = [path stringByStandardizingPath];

  @synchronized(self) {
    if ([_fileDescriptorsByPath objectForKey:path]) {
      NSLog(@"we already have a kevent");
      return YES;
    }

    int fd = open([path fileSystemRepresentation], O_EVTONLY, 0);
    if (fd < 0) {
      NSLog(@"WARNING: Could not create file descriptor for path '%@'. Error code %d.", path, errno);
      return NO;
    }

    [_fileDescriptorsByPath setObject:[NSNumber numberWithInt:fd] forKey:path];

    struct timespec timeout = { 0, 0 };
    struct kevent event;
    int filter = EVFILT_VNODE;
    int flags = EV_ADD | EV_ENABLE | EV_CLEAR;
    int filterFlags = NOTE_WRITE | NOTE_DELETE | NOTE_RENAME;
    EV_SET(&event, fd, filter, flags, filterFlags, 0, path);
    kevent(_kq, &event, 1, NULL, 0, &timeout);
    return YES;
  }
}

- (void)removeKeventForPath:(NSString *)path {
  path = [path stringByStandardizingPath];

  @synchronized(self) {
    NSNumber *fdNumber = [_fileDescriptorsByPath objectForKey:path];
    if (!fdNumber) {
      NSLog(@"WARNING: Could not find file descriptor for path '%@'", path);
      return;
    }
    close([fdNumber integerValue]);
    [_fileDescriptorsByPath removeObjectForKey:path];
  }

}

- (bool)isAtomicWrite:(struct kevent)event {
  if (!event.fflags & NOTE_DELETE) return NO;
  const char *path = [(NSString *)event.udata fileSystemRepresentation];
  bool fileExists = access(path, F_OK) != -1;
  return fileExists;
}

- (void)changePath:(NSString *)path toNewPath:(NSString *)newPath {
  @synchronized(self) {
    NSDictionary *callbacks = [NSDictionary dictionaryWithDictionary:[_callbacksByPath objectForKey:path]];
    [self unwatchPath:path callbackId:nil error:nil];
    for (NSString *callbackId in [callbacks allKeys]) {
      [self watchPath:newPath callback:[callbacks objectForKey:callbackId] callbackId:callbackId];
    }
  }
}

- (void)watch {
  struct kevent event;
  struct timespec timeout = { 5, 0 }; // 5 seconds timeout.

  while (_keepWatching) {
    @autoreleasepool {
      int numberOfEvents = kevent(_kq, NULL, 0, &event, 1, &timeout);
      if (numberOfEvents == 0) {
        continue;
      }

      NSString *eventFlag = nil;
      NSString *newPath = nil;
      NSString *path = [(NSString *)event.udata retain];

      if (event.fflags & NOTE_WRITE) {
        eventFlag = @"contents-change";
      }
      else if ([self isAtomicWrite:event]) {
        eventFlag = @"contents-change";
        // Atomic writes require the kqueue to be recreated
        [self removeKeventForPath:path];
        [self createKeventForPath:path];
      }
      else if (event.fflags & NOTE_DELETE) {
        eventFlag = @"remove";
      }
      else if (event.fflags & NOTE_RENAME) {
        eventFlag = @"move";
        char pathBuffer[MAXPATHLEN];
        fcntl((int)event.ident, F_GETPATH, &pathBuffer);
        close(event.ident);
        newPath = [[NSString stringWithUTF8String:pathBuffer] stringByStandardizingPath];
        if (!newPath) {
          NSLog(@"WARNING: Ignoring rename event for deleted file '%@'", path);
          continue;
        }
      }

      NSDictionary *callbacks;
      @synchronized(self) {
        callbacks = [NSDictionary dictionaryWithDictionary:[_callbacksByPath objectForKey:path]];
      }

      if ([eventFlag isEqual:@"move"]) {
        [self changePath:path toNewPath:newPath];
      }

      if ([eventFlag isEqual:@"remove"]) {
        [self unwatchPath:path callbackId:nil error:nil];
      }

      dispatch_sync(dispatch_get_main_queue(), ^{
        for (NSString *key in callbacks) {
          WatchCallback callback = [callbacks objectForKey:key];
          callback(eventFlag, newPath ? newPath : path);
        }
      });

      [path release];
    }
  }
}

@end
