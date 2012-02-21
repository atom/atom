#import "native_handler.h"
#import "include/cef.h"

@interface NSString (CEF)
+ (NSString *)fromCefV8Value:(const CefRefPtr<CefV8Value>&)value;
@end

@implementation NSString (CEF)

+ (NSString *)fromCefV8Value:(const CefRefPtr<CefV8Value>&)value {
  std::string cc_value = value->GetStringValue().ToString();
  return [NSString stringWithUTF8String:cc_value.c_str()];
}

@end

NativeHandler::NativeHandler() {
  
}

bool NativeHandler::Execute(const CefString& name,
                     CefRefPtr<CefV8Value> object,
                     const CefV8ValueList& arguments,
                     CefRefPtr<CefV8Value>& retval,
                     CefString& exception)
{
  if (name == "exists") {
    NSString *path = [NSString fromCefV8Value:arguments[0]];
    bool exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil];
    retval = CefV8Value::CreateBool(exists);

    return true;
  }
  else if (name == "read") {
    NSString *path = [NSString fromCefV8Value:arguments[0]];

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
  else if (name == "absolute") {
//    NSString *path = [NSString fromCefV8Value:arguments[0]];
//    
//    path = [path stringByStandardizingPath];
//    if ([path characterAtIndex:0] == '/') {
//      return path;
//    }
//    
//    NSString *resolvedPath = [[NSFileManager defaultManager] currentDirectoryPath];
//    resolvedPath = [[resolvedPath stringByAppendingPathComponent:path] stringByStandardizingPath];
//    
//    return resolvedPath;
  }
  
  return false;
};
