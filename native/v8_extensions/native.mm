#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import <CommonCrypto/CommonDigest.h>

#import "atom_application.h"
#import "native.h"
#import "include/cef_base.h"
#import "path_watcher.h"

#import <iostream>
#include <fts.h>

static std::string windowState = "{}";
static NSLock *windowStateLock = [[NSLock alloc] init];

namespace v8_extensions {
  using namespace std;

  NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value);
  void throwException(const CefRefPtr<CefV8Value>& global, CefRefPtr<CefV8Exception> exception, NSString *message);

  Native::Native() : CefV8Handler() {
  }

  void Native::CreateContextBinding(CefRefPtr<CefV8Context> context) {
    const char* methodNames[] = {
      "read", "write", "absolute",
      "remove", "writeToPasteboard", "readFromPasteboard", "quit", "watchPath", "unwatchPath",
      "getWatchedPaths", "unwatchAllPaths", "makeDirectory", "move", "moveToTrash", "reload",
      "md5ForPath", "getPlatform", "setWindowState", "getWindowState", "isMisspelled",
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
    if (name == "read") {
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
