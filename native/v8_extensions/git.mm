#import "git.h"
#import "include/git2.h"
#import "include/cef_base.h"
#import <Cocoa/Cocoa.h>

namespace v8_extensions {

class GitRepository : public CefBase {
  private:
    bool exists;
    git_repository *repo;

  public:
    GitRepository(CefRefPtr<CefV8Value> path) {
      const char *repoPath = path->GetStringValue().ToString().c_str();
      exists = git_repository_open(&repo, repoPath) == GIT_OK;
    }

    ~GitRepository() {
      if (repo)
        git_repository_free(repo);
    }

    CefRefPtr<CefV8Value> GetHead() {
      if (!exists)
        return CefV8Value::CreateNull();

      git_reference *head;
      if (git_repository_head(&head, repo) == GIT_OK) {
        if (git_repository_head_detached(repo) == 1) {
          const git_oid* sha = git_reference_oid(head);
          if (sha) {
            char oid[GIT_OID_HEXSZ + 1];
            git_oid_tostr(oid, GIT_OID_HEXSZ + 1, sha);
            return CefV8Value::CreateString(oid);
          }
        }
        return CefV8Value::CreateString(git_reference_name(head));
      } else
        return CefV8Value::CreateNull();
    }

  IMPLEMENT_REFCOUNTING(GitRepository);
};

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
  if (name == "getRepositoryPath") {
    const char *path = arguments[0]->GetStringValue().ToString().c_str();
    int length = strlen(path);
    char repoPath[GIT_PATH_MAX];
    if (git_repository_discover(repoPath, length, path, 0, "") == GIT_OK)
      retval = CefV8Value::CreateString(repoPath);
    else
      retval = CefV8Value::CreateNull();
    return true;
  }

  if (name == "getRepository") {
    CefRefPtr<CefBase> userData = new GitRepository(arguments[0]);
    retval = CefV8Value::CreateObject(NULL);
    retval->SetUserData(userData);
    return true;
  }

  if (name == "getHead") {
    GitRepository *userData = (GitRepository *)object->GetUserData().get();
    retval = userData->GetHead();
    return true;
  }
  return false;
}

}
