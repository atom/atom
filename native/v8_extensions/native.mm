#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#import "atom_application.h"
#import "native.h"
#import "include/cef_base.h"
#import "path_watcher.h"

#import <iostream>

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
      "writeToPasteboard", "readFromPasteboard", "quit", "watchPath",
      "unwatchPath", "getWatchedPaths", "unwatchAllPaths", "moveToTrash",
      "reload", "setWindowState", "getWindowState", "isMisspelled",
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
    if (name == "writeToPasteboard") {
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
