#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#import "atom_application.h"
#import "native.h"
#import "include/cef_base.h"

#import <iostream>

static std::string windowState = "";
static NSLock *windowStateLock = [[NSLock alloc] init];

namespace v8_extensions {
  using namespace std;

  NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value);
  void throwException(const CefRefPtr<CefV8Value>& global, CefRefPtr<CefV8Exception> exception, NSString *message);

  Native::Native() : CefV8Handler() {
  }

  void Native::CreateContextBinding(CefRefPtr<CefV8Context> context) {
    const char* methodNames[] = {
      "writeToPasteboard", "readFromPasteboard", "quit", "moveToTrash",
      "reload", "setWindowState", "getWindowState", "beep", "crash"
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
    else if (name == "moveToTrash") {
      NSString *sourcePath = stringFromCefV8Value(arguments[0]);
      bool success = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                                  source:[sourcePath stringByDeletingLastPathComponent]
                                                             destination:@""
                                                                   files:[NSArray arrayWithObject:[sourcePath lastPathComponent]]
                                                                     tag:nil];

      if (!success) {
        string exception = "Can not move ";
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

    else if (name == "beep") {
      NSBeep();
    }

    else if (name == "crash") {
      __builtin_trap();
    }

    return false;
  }
  };

  NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value) {
    string cc_value = value->GetStringValue().ToString();
    return [NSString stringWithUTF8String:cc_value.c_str()];
  }

  void throwException(const CefRefPtr<CefV8Value>& global, CefRefPtr<CefV8Exception> exception, NSString *message) {
    CefV8ValueList arguments;

    message = [message stringByAppendingFormat:@"\n%s", exception->GetMessage().ToString().c_str()];
    arguments.push_back(CefV8Value::CreateString(string([message UTF8String], [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding])));

    CefRefPtr<CefV8Value> console = global->GetValue("console");
    console->GetValue("error")->ExecuteFunction(console, arguments);
  }

} // namespace v8_extensions
