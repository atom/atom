#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import <CommonCrypto/CommonDigest.h>

#import "atom_application.h"
#import "native.h"
#import "include/cef_base.h"
#import "path_watcher.h"

#import <iostream>
#include <fts.h>
#include <util.h>
#include <termios.h>
#include <sys/ioctl.h>

static std::string windowState = "{}";
static NSLock *windowStateLock = [[NSLock alloc] init];

namespace v8_extensions {
  using namespace std;

  class IOHandler : public CefV8Handler {
  public:
    bool closed;
    bool interactive;
    IOHandler(NSFileHandle *_stdin, NSTask *_task, bool _interactive) : CefV8Handler(), task(_task), stdin(_stdin), interactive(_interactive) {
      [stdin retain];
      [task retain];
      closed = false;
    };
    ~IOHandler() {
      [stdin release];
      [task release];
    }
    void writeData(NSString *data) {
      @try {
        [stdin writeData:[data dataUsingEncoding:NSUTF8StringEncoding]];
      } @catch (NSException* e) {
      }
    }
    virtual bool Execute(const CefString& name,
                         CefRefPtr<CefV8Value> object,
                         const CefV8ValueList& arguments,
                         CefRefPtr<CefV8Value>& retval,
                         CefString& exception) {
      @autoreleasepool {
        if (name == "write") {
          if (closed) return;
          std::string value = arguments[0]->GetStringValue().ToString();
          NSString *data = [NSString stringWithUTF8String:value.c_str()];
          writeData(data);
          if(arguments[1]->GetBoolValue() == true) {
            closed = true;
            if(interactive)
              writeData([NSString stringWithFormat:@"%c", 4]);
            else
              [stdin closeFile];
          }
        } else if (name == "winsize") {
          int fd = [stdin fileDescriptor];
          unsigned short rows, cols;
          rows = arguments[0]->GetUIntValue();
          cols = arguments[1]->GetUIntValue();
          struct winsize winsize;
          ioctl(fd, TIOCGWINSZ, &winsize);
          if (winsize.ws_row != rows || winsize.ws_col != cols) {
            winsize.ws_row = rows;
            winsize.ws_col = cols;
            ioctl(fd, TIOCSWINSZ, &winsize);
          }
          return true;
        }
        return false;
      }
    };
    IMPLEMENT_REFCOUNTING(IOHandler);
  private:
    NSFileHandle *stdin;
    NSTask *task;
  };

  NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value);
  void throwException(const CefRefPtr<CefV8Value>& global, CefRefPtr<CefV8Exception> exception, NSString *message);

  #define CTRLCODE(c)   ((c)-'A'+1)
  NSFileHandle* usePtyForTask(NSTask* task) {
    NSFileHandle *ptyFileHandle = nil;
    NSFileHandle *ptyMasterHandle = nil;
    int masterFd = 0, slaveFd = 0;
    struct termios term;
    struct winsize window;
    term.c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
    term.c_oflag = OPOST | ONLCR;
    term.c_cflag = CREAD | CS8 | HUPCL;
    term.c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;
    term.c_cc[VEOF] = CTRLCODE('D');
    term.c_cc[VINTR] = CTRLCODE('C');
    term.c_cc[VWERASE] = CTRLCODE('W');
    term.c_cc[VSUSP] = CTRLCODE('Z');
    term.c_cc[VQUIT] = 0x1c;
    term.c_ispeed = B38400;
    term.c_ospeed = B38400;
    window.ws_row = 24;
    window.ws_col = 80;
    openpty(&masterFd, &slaveFd, nil, &term, &window);
    ptyFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:slaveFd];
    ptyMasterHandle = [[NSFileHandle alloc] initWithFileDescriptor:masterFd];
    fcntl(slaveFd, F_SETFD, FD_CLOEXEC);
    fcntl(masterFd, F_SETFD, FD_CLOEXEC);
    [task setStandardOutput:ptyFileHandle];
    [task setStandardError:ptyFileHandle];
    [task setStandardInput:ptyFileHandle];
    [ptyFileHandle release];
    return ptyMasterHandle;
  }

  Native::Native() : CefV8Handler() {
  }

  void Native::CreateContextBinding(CefRefPtr<CefV8Context> context) {
    const char* methodNames[] = {
      "exists", "read", "write", "absolute", "getAllFilePathsAsync", "traverseTree", "isDirectory",
      "isFile", "remove", "writeToPasteboard", "readFromPasteboard", "quit", "watchPath", "unwatchPath",
      "getWatchedPaths", "unwatchAllPaths", "makeDirectory", "move", "moveToTrash", "reload", "lastModified",
      "md5ForPath", "exec", "getPlatform", "setWindowState", "getWindowState", "isMisspelled",
      "getCorrectionsForMisspelling"
    };

    CefRefPtr<CefV8Value> nativeObject = CefV8Value::CreateObject(NULL);
    int arrayLength = sizeof(methodNames) / sizeof(const char *);
    for (int i = 0; i < arrayLength; i++) {
      const char *functionName = methodNames[i];
      CefRefPtr<CefV8Value> function = CefV8Value::CreateFunction(functionName, this);
      nativeObject->SetValue(functionName, function, V8_PROPERTY_ATTRIBUTE_NONE);
    }

    CefRefPtr<CefV8Value> global = context->GetGlobal();
    global->SetValue("$native", nativeObject, V8_PROPERTY_ATTRIBUTE_NONE);
  }

  bool Native::Execute(const CefString& name,
                       CefRefPtr<CefV8Value> object,
                       const CefV8ValueList& arguments,
                       CefRefPtr<CefV8Value>& retval,
                       CefString& exception) {
    @autoreleasepool {
    if (name == "exists") {
      std::string cc_value = arguments[0]->GetStringValue().ToString();
      const char *path = cc_value.c_str();
      retval = CefV8Value::CreateBool(access(path, F_OK) == 0);

      return true;
    }
    else if (name == "read") {
      NSString *path = stringFromCefV8Value(arguments[0]);

      NSError *error = nil;
      NSStringEncoding *encoding = nil;
      NSString *contents = [NSString stringWithContentsOfFile:path usedEncoding:encoding error:&error];

      NSError *binaryFileError = nil;
      if (error) {
        contents = [NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&binaryFileError];
      }

      if (binaryFileError) {
        exception = [[binaryFileError localizedDescription] UTF8String];
      }
      else {
        retval = CefV8Value::CreateString([contents UTF8String]);
      }

      return true;
    }
    else if (name == "write") {
      NSString *path = stringFromCefV8Value(arguments[0]);
      NSString *content = stringFromCefV8Value(arguments[1]);

      NSFileManager *fm = [NSFileManager defaultManager];

      // Create parent directories if they don't exist
      BOOL exists = [fm fileExistsAtPath:[path stringByDeletingLastPathComponent] isDirectory:nil];
      if (!exists) {
        [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
      }

      NSError *error = nil;
      BOOL success = [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];

      if (error) {
        exception = [[error localizedDescription] UTF8String];
      }
      else if (!success) {
        std::string exception = "Cannot write to '";
        exception += [path UTF8String];
        exception += "'";
      }

      return true;
    }
    else if (name == "absolute") {
      NSString *path = stringFromCefV8Value(arguments[0]);

      path = [path stringByStandardizingPath];
      if ([path characterAtIndex:0] == '/') {
        retval = CefV8Value::CreateString([path UTF8String]);
      }

      return true;
    }
    else if (name == "getAllFilePathsAsync") {
      std::string argument = arguments[0]->GetStringValue().ToString();
      CefRefPtr<CefV8Value> callback = arguments[1];
      CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();

      dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
      dispatch_async(queue, ^{
        int rootPathLength = argument.size() + 1;
        char rootPath[rootPathLength];
        strcpy(rootPath, argument.c_str());
        char * const treePaths[] = {rootPath, NULL};

        FTS *tree = fts_open(treePaths, FTS_COMFOLLOW | FTS_PHYSICAL| FTS_NOCHDIR | FTS_NOSTAT, NULL);
        std::vector<std::string> paths;

        if (tree != NULL) {
          FTSENT *entry;
          int arrayIndex = 0;
          while ((entry = fts_read(tree)) != NULL) {
            if (entry->fts_level == 0) {
              continue;
            }

            bool isFile = entry->fts_info == FTS_NSOK;
            if (!isFile) {
              continue;
            }

            int pathLength = entry->fts_pathlen - rootPathLength;
            char relative[pathLength + 1];
            relative[pathLength] = '\0';
            strncpy(relative, entry->fts_path + rootPathLength, pathLength);
            paths.push_back(relative);
          }
        }

        dispatch_queue_t mainQueue = dispatch_get_main_queue();
        dispatch_async(mainQueue, ^{
          context->Enter();
          CefRefPtr<CefV8Value> v8Paths = CefV8Value::CreateArray(paths.size());
          for (int i = 0; i < paths.size(); i++) {
            v8Paths->SetValue(i, CefV8Value::CreateString(paths[i]));
          }
          CefV8ValueList callbackArgs;
          callbackArgs.push_back(v8Paths);
          callback->ExecuteFunction(callback, callbackArgs);
          context->Exit();
        });
      });
      return true;
    }
    else if (name == "traverseTree") {
      std::string argument = arguments[0]->GetStringValue().ToString();
      char rootPath[argument.size() + 1];
      strcpy(rootPath, argument.c_str());
      char * const paths[] = {rootPath, NULL};

      FTS *tree = fts_open(paths, FTS_COMFOLLOW | FTS_PHYSICAL| FTS_NOCHDIR | FTS_NOSTAT, NULL);
      if (tree == NULL) {
        return true;
      }

      CefRefPtr<CefV8Value> onFile = arguments[1];
      CefRefPtr<CefV8Value> onDir = arguments[2];
      CefV8ValueList args;
      FTSENT *entry;
      while ((entry = fts_read(tree)) != NULL) {
        if (entry->fts_level == 0) {
          continue;
        }

        bool isFile = entry->fts_info == FTS_NSOK;
        bool isDir =  entry->fts_info == FTS_D;
        if (!isFile && !isDir) {
          continue;
        }

        args.clear();
        args.push_back(CefV8Value::CreateString(entry->fts_path));
        if (isFile) {
          onFile->ExecuteFunction(onFile, args);
        }
        else {
          CefRefPtr<CefV8Value> enterDir = onDir->ExecuteFunction(onDir, args);
          if(enterDir != NULL && !enterDir->GetBoolValue()) {
            fts_set(tree, entry, FTS_SKIP);
          }
        }
      }

      return true;
    }
    else if (name == "isDirectory") {
      NSString *path = stringFromCefV8Value(arguments[0]);

      BOOL isDir = false;
      BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
      retval = CefV8Value::CreateBool(exists && isDir);

      return true;
    }
    else if (name == "isFile") {
      NSString *path = stringFromCefV8Value(arguments[0]);

      BOOL isDir = false;
      BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
      retval = CefV8Value::CreateBool(exists && !isDir);

      return true;
    }
    else if (name == "remove") {
      NSString *path = stringFromCefV8Value(arguments[0]);

      NSError *error = nil;
      [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

      if (error) {
        exception = [[error localizedDescription] UTF8String];
      }

      return true;
    }
    else if (name == "writeToPasteboard") {
      NSString *text = stringFromCefV8Value(arguments[0]);

      NSPasteboard *pb = [NSPasteboard generalPasteboard];
      [pb declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
      [pb setString:text forType:NSStringPboardType];

      return true;
    }
    else if (name == "readFromPasteboard") {
      NSPasteboard *pb = [NSPasteboard generalPasteboard];
      NSArray *results = [pb readObjectsForClasses:[NSArray arrayWithObjects:[NSString class], nil] options:nil];
      if (results) {
        retval = CefV8Value::CreateString([[results objectAtIndex:0] UTF8String]);
      }

      return true;
    }
    else if (name == "quit") {
      [NSApp terminate:nil];
      return true;
    }
    else if (name == "watchPath") {
      NSString *path = stringFromCefV8Value(arguments[0]);
      CefRefPtr<CefV8Value> function = arguments[1];

      CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();

      WatchCallback callback = ^(NSString *eventType, NSString *path) {
        context->Enter();

        CefV8ValueList args;

        args.push_back(CefV8Value::CreateString(std::string([eventType UTF8String], [eventType lengthOfBytesUsingEncoding:NSUTF8StringEncoding])));
        args.push_back(CefV8Value::CreateString(std::string([path UTF8String], [path lengthOfBytesUsingEncoding:NSUTF8StringEncoding])));
        function->ExecuteFunction(function, args);

        context->Exit();
      };

      PathWatcher *pathWatcher = [PathWatcher pathWatcherForContext:CefV8Context::GetCurrentContext()];
      NSString *watchId = [pathWatcher watchPath:path callback:[[callback copy] autorelease]];
      if (watchId) {
        retval = CefV8Value::CreateString([watchId UTF8String]);
      }
      else {
        exception = std::string("Failed to watch path '") + std::string([path UTF8String]) +  std::string("' (it may not exist)");
      }

      return true;
    }
    else if (name == "unwatchPath") {
      NSString *path = stringFromCefV8Value(arguments[0]);
      NSString *callbackId = stringFromCefV8Value(arguments[1]);
      NSError *error = nil;
      PathWatcher *pathWatcher = [PathWatcher pathWatcherForContext:CefV8Context::GetCurrentContext()];
      [pathWatcher unwatchPath:path callbackId:callbackId error:&error];

      if (error) {
        exception = [[error localizedDescription] UTF8String];
      }

      return true;
    }
    else if (name == "getWatchedPaths") {
      PathWatcher *pathWatcher = [PathWatcher pathWatcherForContext:CefV8Context::GetCurrentContext()];
      NSArray *paths = [pathWatcher watchedPaths];

      CefRefPtr<CefV8Value> pathsArray = CefV8Value::CreateArray([paths count]);

      for (int i = 0; i < [paths count]; i++) {
        CefRefPtr<CefV8Value> path = CefV8Value::CreateString([[paths objectAtIndex:i] UTF8String]);
        pathsArray->SetValue(i, path);
      }
      retval = pathsArray;

      return true;
    }
    else if (name == "unwatchAllPaths") {
      PathWatcher *pathWatcher = [PathWatcher pathWatcherForContext:CefV8Context::GetCurrentContext()];
      [pathWatcher unwatchAllPaths];
      return true;
    }
    else if (name == "makeDirectory") {
      NSString *path = stringFromCefV8Value(arguments[0]);
      NSFileManager *fm = [NSFileManager defaultManager];
      NSError *error = nil;
      [fm createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];

      if (error) {
        exception = [[error localizedDescription] UTF8String];
      }

      return true;
    }
    else if (name == "move") {
      NSString *sourcePath = stringFromCefV8Value(arguments[0]);
      NSString *targetPath = stringFromCefV8Value(arguments[1]);
      NSFileManager *fm = [NSFileManager defaultManager];

      NSError *error = nil;
      [fm moveItemAtPath:sourcePath toPath:targetPath error:&error];

      if (error) {
        exception = [[error localizedDescription] UTF8String];
      }

      return true;
    }
    else if (name == "moveToTrash") {
      NSString *sourcePath = stringFromCefV8Value(arguments[0]);
      bool success = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                                  source:[sourcePath stringByDeletingLastPathComponent]
                                                             destination:@""
                                                                   files:[NSArray arrayWithObject:[sourcePath lastPathComponent]]
                                                                     tag:nil];

      if (!success) {
        std::string exception = "Can not move ";
        exception += [sourcePath UTF8String];
        exception += " to trash.";
      }

      return true;
    }
    else if (name == "reload") {
      CefV8Context::GetCurrentContext()->GetBrowser()->ReloadIgnoreCache();
    }
    else if (name == "lastModified") {
      NSString *path = stringFromCefV8Value(arguments[0]);
      NSFileManager *fm = [NSFileManager defaultManager];

      NSError *error = nil;
      NSDictionary *attributes = [fm attributesOfItemAtPath:path error:&error];

      if (error) {
        exception = [[error localizedDescription] UTF8String];
      }

      NSDate *lastModified = [attributes objectForKey:NSFileModificationDate];
      retval = CefV8Value::CreateDate(CefTime([lastModified timeIntervalSince1970]));
      return true;
    }
    else if (name == "md5ForPath") {
      NSString *path = stringFromCefV8Value(arguments[0]);
      unsigned char outputData[CC_MD5_DIGEST_LENGTH];

      NSData *inputData = [[NSData alloc] initWithContentsOfFile:path];
      CC_MD5([inputData bytes], [inputData length], outputData);
      [inputData release];

      NSMutableString *hash = [[NSMutableString alloc] init];

      for (NSUInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", outputData[i]];
      }

      retval = CefV8Value::CreateString([hash UTF8String]);
      return true;
    }
    else if (name == "exec") {
      NSString *command = stringFromCefV8Value(arguments[0]);
      CefRefPtr<CefV8Value> options = arguments[1];
      CefRefPtr<CefV8Value> callback = arguments[2];
      bool interactive = options->GetValue("interactive")->GetBoolValue();
      NSFileHandle *stdout;
      NSFileHandle *stderr = nil;
      NSFileHandle *stdin;

      NSTask *task = [[NSTask alloc] init];
      if (interactive) {
        [task setLaunchPath:command];
        [task setEnvironment:[NSDictionary dictionaryWithObjectsAndKeys: @"/bin/bash", @"SHELL", @"xterm-256color", @"TERM", [@"~" stringByExpandingTildeInPath], @"HOME", nil]];
        [task setArguments:[NSArray arrayWithObject:@"-l"]];
        stdin = stdout = usePtyForTask(task);
      } else {
        [task setLaunchPath:@"/bin/sh"];
        [task setArguments:[NSArray arrayWithObjects:@"-l", @"-c", command, nil]];
        NSPipe *stdoutP = [NSPipe pipe];
        NSPipe *stderrP = [NSPipe pipe];
        NSPipe *stdinP = [NSPipe pipe];
        stdout = stdoutP.fileHandleForReading;
        stderr = stderrP.fileHandleForReading;
        stdin = stdinP.fileHandleForWriting;
        [task setStandardOutput:stdoutP];
        [task setStandardError:stderrP];
        [task setStandardInput:stdinP];
      }
      IOHandler *iohandler = new IOHandler(stdin, task, interactive);

      CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();
      void (^outputHandle)(NSString *contents, CefRefPtr<CefV8Value> function) = nil;
      void (^taskTerminatedHandle)(NSString *output, NSString *errorOutput) = nil;

      outputHandle = ^(NSString *contents, CefRefPtr<CefV8Value> function) {
        context->Enter();

        CefV8ValueList args;
        args.push_back(CefV8Value::CreateString(std::string([contents UTF8String], [contents lengthOfBytesUsingEncoding:NSUTF8StringEncoding])));
        CefRefPtr<CefV8Value> retval = function->ExecuteFunction(function, args);

        if (function->HasException()) {
          throwException(context->GetGlobal(), function->GetException(), @"Error thrown in OutputHandle");
        }

        context->Exit();
      };

      taskTerminatedHandle = ^(NSString *output, NSString *errorOutput) {
        context->Enter();

        CefV8ValueList args;
        args.push_back(CefV8Value::CreateInt([task terminationStatus]));
        args.push_back(CefV8Value::CreateString([output UTF8String]));
        args.push_back(CefV8Value::CreateString([errorOutput UTF8String]));

        callback->ExecuteFunction(callback, args);

        if (callback->HasException()) {
          throwException(context->GetGlobal(), callback->GetException(), @"Error thrown in TaskTerminatedHandle");
        }

        context->Exit();

        stdout.readabilityHandler = nil;
        if (stderr)
          stderr.readabilityHandler = nil;
        if(interactive)
          [stdout closeFile];
      };

      task.terminationHandler = ^(NSTask *) {
        @synchronized(task) {
          NSString *output = @"";
          NSString *errorOutput = @"";
          if(!interactive) {
            NSData *outputData = [stdout readDataToEndOfFile];
            output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
            if(stderr) {
              NSData *errorData = [stderr readDataToEndOfFile];
              errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            }
          }
          dispatch_sync(dispatch_get_main_queue(), ^() {
            taskTerminatedHandle(output, errorOutput);
          });
          [output release];
          [errorOutput release];
        }
      };

      CefRefPtr<CefV8Value> stdoutFunction = options->GetValue("stdout");
      if (stdoutFunction->IsFunction()) {
        stdout.readabilityHandler = ^(NSFileHandle *fileHandle) {
          @synchronized(task) {
           NSData *data;
            @try {
              data = [fileHandle availableData];
            }
            @catch (NSException *e) {
              return;
            }
            NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            dispatch_sync(dispatch_get_main_queue(), ^() {
              outputHandle(contents, stdoutFunction);
            });
            [contents release];
          }
        };
      }

      CefRefPtr<CefV8Value> stderrFunction = options->GetValue("stderr");
      if (stderr && stderrFunction->IsFunction()) {
        stderr.readabilityHandler = ^(NSFileHandle *fileHandle) {
          @synchronized(task) {
            NSData *data = [fileHandle availableData];
            NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            dispatch_sync(dispatch_get_main_queue(), ^() {
              outputHandle(contents, stderrFunction);
            });
            [contents release];
          }
        };
      }

      CefRefPtr<CefV8Value> currentWorkingDirectory = options->GetValue("cwd");
      if (!currentWorkingDirectory->IsUndefined() && !currentWorkingDirectory->IsNull()) {
        [task setCurrentDirectoryPath:stringFromCefV8Value(currentWorkingDirectory)];
      }

      context->Enter();
      CefRefPtr<CefV8Value> iocallback = CefV8Value::CreateObject(NULL);
      iocallback->SetValue("write", CefV8Value::CreateFunction("write", iohandler), V8_PROPERTY_ATTRIBUTE_NONE);
      iocallback->SetValue("winsize", CefV8Value::CreateFunction("winsize", iohandler), V8_PROPERTY_ATTRIBUTE_NONE);
      retval = iocallback;
      context->Exit();

      [task launch];

      return true;
    }
    else if (name == "getPlatform") {
      retval = CefV8Value::CreateString("mac");
      return true;
    }

    else if (name == "setWindowState") {
      [windowStateLock lock];
      windowState = arguments[0]->GetStringValue().ToString();
      [windowStateLock unlock];
      return true;
    }

    else if (name == "getWindowState") {
      [windowStateLock lock];
      retval = CefV8Value::CreateString(windowState);
      [windowStateLock unlock];
      return true;
    }

    else if (name == "isMisspelled") {
      NSString *word = stringFromCefV8Value(arguments[0]);
      NSSpellChecker *spellChecker = [NSSpellChecker sharedSpellChecker];
      @synchronized(spellChecker) {
        NSRange range = [spellChecker checkSpellingOfString:word startingAt:0];
        retval = CefV8Value::CreateBool(range.length > 0);
      }
      return true;
    }

    else if (name == "getCorrectionsForMisspelling") {
      NSString *misspelling = stringFromCefV8Value(arguments[0]);
      NSSpellChecker *spellChecker = [NSSpellChecker sharedSpellChecker];
      @synchronized(spellChecker) {
        NSString *language = [spellChecker language];
        NSRange range;
        range.location = 0;
        range.length = [misspelling length];
        NSArray *guesses = [spellChecker guessesForWordRange:range inString:misspelling language:language inSpellDocumentWithTag:0];
        CefRefPtr<CefV8Value> v8Guesses = CefV8Value::CreateArray([guesses count]);
        for (int i = 0; i < [guesses count]; i++) {
          v8Guesses->SetValue(i, CefV8Value::CreateString([[guesses objectAtIndex:i] UTF8String]));
        }
        retval = v8Guesses;
      }
      return true;
    }

    return false;
  }
  };

  NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value) {
    std::string cc_value = value->GetStringValue().ToString();
    return [NSString stringWithUTF8String:cc_value.c_str()];
  }

  void throwException(const CefRefPtr<CefV8Value>& global, CefRefPtr<CefV8Exception> exception, NSString *message) {
    CefV8ValueList arguments;

    message = [message stringByAppendingFormat:@"\n%s", exception->GetMessage().ToString().c_str()];
    arguments.push_back(CefV8Value::CreateString(std::string([message UTF8String], [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding])));

    CefRefPtr<CefV8Value> console = global->GetValue("console");
    console->GetValue("error")->ExecuteFunction(console, arguments);
  }

} // namespace v8_extensions
