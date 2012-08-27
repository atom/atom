#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import <CommonCrypto/CommonDigest.h>

#import "atom_application.h"
#import "native_handler.h"
#import "include/cef_base.h"
#import "path_watcher.h"

#import <iostream>

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

NativeHandler::NativeHandler() : CefV8Handler() {  
  std::string extensionCode =  "var $native = {}; (function() {";
  
  const char *functionNames[] = {"exists", "alert", "read", "write", "absolute", "list", "isFile", "isDirectory", "remove", "asyncList", "open", "openDialog", "quit", "writeToPasteboard", "readFromPasteboard", "showDevTools", "toggleDevTools", "newWindow", "saveDialog", "exit", "watchPath", "unwatchPath", "makeDirectory", "move", "moveToTrash", "reload", "lastModified", "md5ForPath", "exec", "getPlatform"};
  NSUInteger arrayLength = sizeof(functionNames) / sizeof(const char *);
  for (NSUInteger i = 0; i < arrayLength; i++) {
    std::string functionName = std::string(functionNames[i]);
    extensionCode += "native function " + functionName + "(); $native." + functionName + " = " + functionName + ";";
  }
  
  extensionCode += "})();";
  
  // Register the extension.
  CefRegisterExtension("v8/test", extensionCode, this);
}

bool NativeHandler::Execute(const CefString& name,
                     CefRefPtr<CefV8Value> object,
                     const CefV8ValueList& arguments,
                     CefRefPtr<CefV8Value>& retval,
                     CefString& exception) {
  if (name == "exists") {
    NSString *path = stringFromCefV8Value(arguments[0]);
    bool exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil];
    retval = CefV8Value::CreateBool(exists);

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
  else if (name == "list") {
    NSString *path = stringFromCefV8Value(arguments[0]);
    bool recursive = arguments[1]->GetBoolValue();
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *relativePaths = nil;
    NSError *error = nil;
    
    if (recursive) {
      relativePaths = [fm subpathsOfDirectoryAtPath:path error:&error];
    }
    else {
      relativePaths = [fm contentsOfDirectoryAtPath:path error:&error];
    }
    
    if (error) {
      exception = [[error localizedDescription] UTF8String];
    }
    else {
      retval = CefV8Value::CreateArray(relativePaths.count);
      for (NSUInteger i = 0; i < relativePaths.count; i++) {
        NSString *relativePath = [relativePaths objectAtIndex:i];
        NSString *fullPath = [path stringByAppendingPathComponent:relativePath];
        retval->SetValue(i, CefV8Value::CreateString([fullPath UTF8String]));
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
  else if (name == "asyncList") {    
    return false;
  }
  else if (name == "alert") {
    NSString *message = stringFromCefV8Value(arguments[0]);
    NSString *detailedMessage = stringFromCefV8Value(arguments[1]);
      
    CefRefPtr<CefV8Value> buttonNamesAndCallbacks;
    if (arguments.size() < 3) {
      buttonNamesAndCallbacks = CefV8Value::CreateArray(0);
    }
    else {
      buttonNamesAndCallbacks = arguments[2];
    }
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:message];
    [alert setInformativeText:detailedMessage];
    
    for (int i = 0; i < buttonNamesAndCallbacks->GetArrayLength(); i++) {
      std::string title = buttonNamesAndCallbacks->GetValue(i)->GetValue(0)->GetStringValue().ToString();
      NSString *buttonTitle = [NSString stringWithUTF8String:title.c_str()];
      NSButton *button = [alert addButtonWithTitle:buttonTitle];
      [button setTag:i];
    }
    
    NSUInteger buttonTag = [alert runModal];    
    
    if (buttonNamesAndCallbacks->GetArrayLength() == 0) { // No button title if there were no buttons specified.
      return true; 
    }
    
    CefRefPtr<CefV8Value> callback = buttonNamesAndCallbacks->GetValue(buttonTag)->GetValue(1);
    CefV8ValueList args;
		callback->SetRethrowExceptions(true);
    callback->ExecuteFunction(callback, args);
      
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
  else if (name == "openDialog") {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
      NSURL *url = [[panel URLs] lastObject];
      retval = CefV8Value::CreateString([[url path] UTF8String]);
    }
    else {
      retval = CefV8Value::CreateNull();
    }
      
    return true;
  }
  else if (name == "open") {
    NSString *path = stringFromCefV8Value(arguments[0]);
    [NSApp open:path];
    
    return true;
  }
  else if (name == "newWindow") {
    [(AtomApplication *)NSApp open:nil];

    return true;
  }
  else if (name == "saveDialog") {
    NSSavePanel *panel = [NSSavePanel savePanel];
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
      NSURL *url = [panel URL];
      retval = CefV8Value::CreateString([[url path] UTF8String]);
    }
    else {
      return CefV8Value::CreateNull();
    }
    
    return true;
  }
  else if (name == "quit") {
    [NSApp terminate:nil];
    return true;
  }
  else if (name == "showDevTools") {
//    CefV8Context::GetCurrentContext()->GetBrowser()->ShowDevTools();
    return false;
  }  
  else if (name == "toggleDevTools") {
//    [[[NSApp keyWindow] windowController] toggleDevTools];
    return false;
  }
  else if (name == "exit") {
    int exitStatus = 0;
    if (arguments.size() > 0) exitStatus = arguments[0]->GetIntValue();
    
    exit(exitStatus);
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