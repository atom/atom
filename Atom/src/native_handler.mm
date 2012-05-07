#import "native_handler.h"
#import "include/cef_base.h"
#import "Atom.h"
#import "AtomController.h"
#import "client_handler.h"
#import "PathWatcher.h"

#define MY_EXCEPTION_TRY @try {
#define MY_EXCEPTION_HANDLE } @catch (NSException *localException) {}

NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value) {
  std::string cc_value = value->GetStringValue().ToString();
  return [NSString stringWithUTF8String:cc_value.c_str()];
}

NativeHandler::NativeHandler() : CefV8Handler() {  
  m_object = CefV8Value::CreateObject(NULL, NULL);
  
  const char *functionNames[] = {"exists", "alert", "read", "write", "absolute", "list", "isFile", "isDirectory", "remove", "asyncList", "open", "openDialog", "quit", "writeToPasteboard", "readFromPasteboard", "showDevTools", "newWindow", "saveDialog", "exit", "watchPath", "unwatchPath", "makeDirectory", "move", "moveToTrash"};
  NSUInteger arrayLength = sizeof(functionNames) / sizeof(const char *);
  for (NSUInteger i = 0; i < arrayLength; i++) {
    const char *functionName = functionNames[i];
    CefRefPtr<CefV8Value> function = CefV8Value::CreateFunction(functionName, this);
    m_object->SetValue(functionName, function, V8_PROPERTY_ATTRIBUTE_NONE);
  }
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
      retval = CefV8Value::CreateArray();      
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
      CefRefPtr<CefV8Value> paths = CefV8Value::CreateArray();      
      for (NSUInteger i = 0; i < relativePaths.count; i++) {
        NSString *relativePath = [relativePaths objectAtIndex:i];
        NSString *fullPath = [path stringByAppendingPathComponent:relativePath];
        paths->SetValue(i, CefV8Value::CreateString([fullPath UTF8String]));
      }
      
      CefV8ValueList args; 
      args.push_back(paths);
      CefRefPtr<CefV8Exception> e;
      arguments[2]->ExecuteFunction(arguments[2], args, retval, e, true);
      if (e) exception = e->GetMessage();
    }
    
    return true;
  }
  else if (name == "alert") {
    NSString *message = stringFromCefV8Value(arguments[0]);
    NSString *detailedMessage = stringFromCefV8Value(arguments[1]);
    CefRefPtr<CefV8Value> buttons = arguments[2];
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:message];
    [alert setInformativeText:detailedMessage];
    
    std::vector<CefString> buttonTitles;
    std::vector<CefString>::iterator iter;
    NSMutableDictionary *titleForTag = [NSMutableDictionary dictionary];
    
    buttons->GetKeys(buttonTitles);
    
    for (iter = buttonTitles.begin(); iter != buttonTitles.end(); iter++) {
      NSString *buttonTitle = [NSString stringWithUTF8String:(*iter).ToString().c_str()];
      NSButton *button = [alert addButtonWithTitle:buttonTitle];
      [titleForTag setObject:buttonTitle forKey:[NSNumber numberWithInt:button.tag]];
    }
    
    NSUInteger buttonTag = [alert runModal];
    const char *buttonTitle = [[titleForTag objectForKey:[NSNumber numberWithInt:buttonTag]] UTF8String];
    CefRefPtr<CefV8Value> callback = buttons->GetValue(buttonTitle);
    
    CefV8ValueList args; 
    CefRefPtr<CefV8Exception> e;
    callback->ExecuteFunction(callback  , args, retval, e, true);
    if (e) exception = e->GetMessage();
      
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
    [(Atom *)NSApp open:nil];

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
    CefV8Context::GetCurrentContext()->GetBrowser()->ShowDevTools();
    return true;
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
    
    WatchCallback callback = ^(NSArray *eventList) {
      context->Enter();
      
      CefV8ValueList args;
      CefRefPtr<CefV8Value> retval;
      CefRefPtr<CefV8Exception> e;
      
      CefRefPtr<CefV8Value> eventObject = CefV8Value::CreateObject(NULL, NULL);
      for (NSString *event in eventList) {
        eventObject->SetValue([event UTF8String], CefV8Value::CreateBool(true), V8_PROPERTY_ATTRIBUTE_NONE);
      }
      
      args.push_back(eventObject);
      function->ExecuteFunction(function, args, retval, e, true);
      
      context->Exit();
    };

    NSString *watchId = [PathWatcher watchPath:path callback:[[callback copy] autorelease]];
    retval = CefV8Value::CreateString([watchId UTF8String]);
    
    return true;
  }
  else if (name == "unwatchPath") {
    NSString *path = stringFromCefV8Value(arguments[0]);
    NSString *callbackId = stringFromCefV8Value(arguments[1]);
    NSError *error = nil;
    [PathWatcher unwatchPath:path callbackId:callbackId error:&error];
    
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
  return false;
};