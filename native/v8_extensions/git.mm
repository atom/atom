#import "git.h"
#import "include/git2.h"
#import "include/cef_base.h"
#import <Cocoa/Cocoa.h>

namespace v8_extensions {

Git::Git() : CefV8Handler() {
  NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/git.js"];
  NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  CefRegisterExtension("v8/git", [extensionCode UTF8String], this);
}

bool Git::Execute(const CefString& name,
                     CefRefPtr<CefV8Value> object,
                     const CefV8ValueList& arguments,
                     CefRefPtr<CefV8Value>& retval,
                     CefString& exception) {
  if (name == "isRepository") {
    const char *path = arguments[0]->GetStringValue().ToString().c_str();
    int length = strlen(path);
    char repoPath[length];
    bool isRepository = git_repository_discover(repoPath, length, path, 0, "") == GIT_OK;
    retval = CefV8Value::CreateBool(isRepository);
    return true;
  }

  return false;
}

}
