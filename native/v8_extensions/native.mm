#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import <CommonCrypto/CommonDigest.h>

#import "atom_application.h"
#import "native.h"
#import "include/cef_base.h"
#import "path_watcher.h"

#import <iostream>

#include <fts.h>

namespace v8_extensions {

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

Native::Native() : CefV8Handler() {
  NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/native.js"];
  NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  CefRegisterExtension("v8/native", [extensionCode UTF8String], this);
}

bool Native::Execute(const CefString& name,
                     CefRefPtr<CefV8Value> object,
                     const CefV8ValueList& arguments,
                     CefRefPtr<CefV8Value>& retval,
                     CefString& exception) {
  if (name == "exists") {
    std::string cc_value = arguments[0]->GetStringValue().ToString();
    const char *path = cc_value.c_str();
    retval = CefV8Value::CreateBool(access(path, F_OK) == 0);

    return true;
  }
  else if (name == "read") {
    NSString *path = stringFromCefV8Value(arguments[0]);

    NSError *error = nil;
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

    if (error) {
      exception = [[error localizedDescription] UTF8String];
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
  else if (name == "traverseTree") {
      std::string argument = arguments[0]->GetStringValue().ToString();
      int rootPathLength = argument.size() + 1;
      char rootPath[rootPathLength];
      strcpy(rootPath, argument.c_str());
      char * const paths[] = {rootPath, NULL};

      CefRefPtr<CefV8Value> function = arguments[1];
      CefV8ValueList args;
      FTS *tree = fts_open(paths, FTS_NOCHDIR | FTS_NOSTAT, NULL);
      if (tree != NULL) {
          FTSENT *entry;
          while ((entry = fts_read(tree)) != NULL) {
              if (entry->fts_level == 0)
                  continue;
              if ((entry->fts_info & FTS_D) != 0 || (entry->fts_info & FTS_F) != 0) {
                  int pathLength = entry->fts_pathlen - rootPathLength;
                  char relative[pathLength + 1];
                  relative[pathLength] = '\0';
                  strncpy(relative, entry->fts_path + rootPathLength, pathLength);
                  args.clear();
                  args.push_back(CefV8Value::CreateString(relative));
                  args.push_back(CefV8Value::CreateBool((entry->fts_info & FTS_F) != 0));
                  if (!function->ExecuteFunction(function, args)->GetBoolValue())
                    fts_set(tree, entry, FTS_SKIP);
              }
          }
      }

      return true;
  }
  else if (name == "list") {
    NSString *path = stringFromCefV8Value(arguments[0]);
    bool recursive = arguments[1]->GetBoolValue();

    if (!path or [path length] == 0) {
      exception = "$native.list requires a path argument";
      return true;
    }

    std::string argument = arguments[0]->GetStringValue().ToString();
    char rootPath[argument.size() + 1];
    strcpy(rootPath, argument.c_str());
    char * const paths[] = {rootPath, NULL};
    FTS *tree = fts_open(paths, FTS_NOCHDIR | FTS_NOSTAT, NULL);
    retval = CefV8Value::CreateArray(0);
    int index = 0;
    if (tree != NULL) {
      FTSENT *entry;
      while ((entry = fts_read(tree)) != NULL) {
        if (entry->fts_level == 0)
          continue;
        if (!recursive)
          fts_set(tree, entry, FTS_SKIP);
        if ((entry->fts_info & FTS_D) != 0 || (entry->fts_info & FTS_F) != 0)
          retval->SetValue(index++, CefV8Value::CreateString(entry->fts_path));
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

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
    [task setArguments:[NSArray arrayWithObjects:@"-l", @"-c", command, nil]];

    NSPipe *stdout = [NSPipe pipe];
    NSPipe *stderr = [NSPipe pipe];
    [task setStandardOutput:stdout];
    [task setStandardError:stderr];

    CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();
    void (^outputHandle)(NSFileHandle *fileHandle, CefRefPtr<CefV8Value> function) = nil;
    void (^taskTerminatedHandle)() = nil;

    outputHandle = ^(NSFileHandle *fileHandle, CefRefPtr<CefV8Value> function) {
      context->Enter();

      NSData *data = [fileHandle availableData];
      NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

      CefV8ValueList args;
      args.push_back(CefV8Value::CreateString(std::string([contents UTF8String], [contents lengthOfBytesUsingEncoding:NSUTF8StringEncoding])));
      CefRefPtr<CefV8Value> retval = function->ExecuteFunction(function, args);

      if (function->HasException()) {
        throwException(context->GetGlobal(), function->GetException(), @"Error thrown in OutputHandle");
      }

      [contents release];
      context->Exit();
    };

    taskTerminatedHandle = ^() {
      context->Enter();
      NSString *output = [[NSString alloc] initWithData:[[stdout fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
      NSString *errorOutput  = [[NSString alloc] initWithData:[[task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];

      CefV8ValueList args;

      args.push_back(CefV8Value::CreateInt([task terminationStatus]));
      args.push_back(CefV8Value::CreateString([output UTF8String]));
      args.push_back(CefV8Value::CreateString([errorOutput UTF8String]));

      callback->ExecuteFunction(callback, args);

      if (callback->HasException()) {
        throwException(context->GetGlobal(), callback->GetException(), @"Error thrown in TaskTerminatedHandle");
      }

      context->Exit();

      stdout.fileHandleForReading.writeabilityHandler = nil;
      stderr.fileHandleForReading.writeabilityHandler = nil;
    };

    task.terminationHandler = ^(NSTask *) {
      dispatch_sync(dispatch_get_main_queue(), taskTerminatedHandle);
    };

    CefRefPtr<CefV8Value> stdoutFunction = options->GetValue("stdout");
    if (stdoutFunction->IsFunction()) {
      stdout.fileHandleForReading.writeabilityHandler = ^(NSFileHandle *fileHandle) {
        dispatch_sync(dispatch_get_main_queue(), ^() {
          outputHandle(fileHandle, stdoutFunction);
        });
      };
    }

    CefRefPtr<CefV8Value> stderrFunction = options->GetValue("stderr");
    if (stderrFunction->IsFunction()) {
      stderr.fileHandleForReading.writeabilityHandler = ^(NSFileHandle *fileHandle) {
        dispatch_sync(dispatch_get_main_queue(), ^() {
          outputHandle(fileHandle, stderrFunction);
        });
      };
    }

    [task launch];

    return true;
  }
  else if (name == "getPlatform") {
    retval = CefV8Value::CreateString("mac");
    return true;
  }

  return false;
};

} // namespace v8_extensions
