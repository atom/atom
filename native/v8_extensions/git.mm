#import "git.h"
#import "include/git2.h"
#import <Cocoa/Cocoa.h>

namespace v8_extensions {

class GitRepository : public CefBase {
private:
  bool exists;
  git_repository *repo;

public:
  GitRepository(const char *pathInRepo) {
    exists = git_repository_open_ext(&repo, pathInRepo, 0, NULL) == GIT_OK;
  }

  ~GitRepository() {
    if (repo)
      git_repository_free(repo);
  }

  CefRefPtr<CefV8Value> GetPath() {
    if (exists)
      return CefV8Value::CreateString(git_repository_path(repo));
    else
      return CefV8Value::CreateNull();
  }

  CefRefPtr<CefV8Value> GetHead() {
    if (!exists)
      return CefV8Value::CreateNull();

    git_reference *head;
    if (git_repository_head(&head, repo) == GIT_OK) {
      if (git_repository_head_detached(repo) == 1) {
        const git_oid* sha = git_reference_target(head);
        if (sha) {
          char oid[GIT_OID_HEXSZ + 1];
          git_oid_tostr(oid, GIT_OID_HEXSZ + 1, sha);
          git_reference_free(head);
          return CefV8Value::CreateString(oid);
        }
      }

      CefRefPtr<CefV8Value> result =  CefV8Value::CreateString(git_reference_name(head));
      git_reference_free(head);
      return result;
    }

    return CefV8Value::CreateNull();
  }

  CefRefPtr<CefV8Value> IsIgnored(const char *path) {
    if (!exists) {
      return CefV8Value::CreateBool(false);
    }

    int ignored;
    if (git_ignore_path_is_ignored(&ignored, repo, path) == GIT_OK) {
      return CefV8Value::CreateBool(ignored == 1);
    }
    else {
      return CefV8Value::CreateBool(false);
    }
  }

  CefRefPtr<CefV8Value> GetStatus(const char *path) {
    if (!exists) {
      return CefV8Value::CreateInt(0);
    }

    git_index* index;
    if (git_repository_index(&index, repo) == GIT_OK) {
      git_index_read(index);
      git_index_free(index);
    }

    unsigned int status = 0;
    if (git_status_file(&status, repo, path) == GIT_OK) {
      return CefV8Value::CreateInt(status);
    }
    else {
      return CefV8Value::CreateInt(0);
    }
  }

  CefRefPtr<CefV8Value> CheckoutHead(const char *path) {
    if (!exists) {
      return CefV8Value::CreateBool(false);
    }

    char *copiedPath = (char *)malloc(sizeof(char) * (strlen(path) + 1));
    strcpy(copiedPath, path);
    git_checkout_opts options = GIT_CHECKOUT_OPTS_INIT;
    options.checkout_strategy = GIT_CHECKOUT_UPDATE_MODIFIED;
    git_strarray paths;
    paths.count = 1;
    paths.strings = &copiedPath;
    options.paths = paths;

    int result = git_checkout_head(repo, &options);
    free(copiedPath);
    if (result == GIT_OK) {
      return CefV8Value::CreateBool(true);
    }
    else {
      return CefV8Value::CreateBool(false);
    }
  }

  CefRefPtr<CefV8Value> GetDiffStats(const char *path) {
    if (!exists) {
      return CefV8Value::CreateNull();
    }

    git_reference *head;
    if (git_repository_head(&head, repo) != GIT_OK) {
      return CefV8Value::CreateNull();
    }

    const git_oid* sha = git_reference_target(head);
    git_commit *commit;
    int commitStatus = git_commit_lookup(&commit, repo, sha);
    git_reference_free(head);
    if (commitStatus != GIT_OK) {
      return CefV8Value::CreateNull();
    }

    git_tree *tree;
    int treeStatus = git_commit_tree(&tree, commit);
    git_commit_free(commit);
    if (treeStatus != GIT_OK) {
      return CefV8Value::CreateNull();
    }

    char *copiedPath = (char *)malloc(sizeof(char) * (strlen(path) + 1));
    strcpy(copiedPath, path);
    git_diff_options options = GIT_DIFF_OPTIONS_INIT;
    git_strarray paths;
    paths.count = 1;
    paths.strings = &copiedPath;
    options.pathspec = paths;
    options.context_lines = 1;
    options.flags = GIT_DIFF_DISABLE_PATHSPEC_MATCH;

    git_diff_list *diffs;
    int diffStatus = git_diff_tree_to_workdir(&diffs, repo, tree, &options);
    free(copiedPath);
    if (diffStatus != GIT_OK || git_diff_num_deltas(diffs) != 1) {
      return CefV8Value::CreateNull();
    }

    git_diff_patch *patch;
    int patchStatus = git_diff_get_patch(&patch, NULL, diffs, 0);
    git_diff_list_free(diffs);
    if (patchStatus != GIT_OK) {
      return CefV8Value::CreateNull();
    }

    int added = 0;
    int deleted = 0;
    int hunks = git_diff_patch_num_hunks(patch);
    for (int i = 0; i < hunks; i++) {
      int lines = git_diff_patch_num_lines_in_hunk(patch, i);
      for (int j = 0; j < lines; j++) {
        char lineType;
        if (git_diff_patch_get_line_in_hunk(&lineType, NULL, NULL, NULL, NULL, patch, i, j) == GIT_OK) {
          if (lineType == GIT_DIFF_LINE_ADDITION) {
            added++;
          } else if(lineType == GIT_DIFF_LINE_DELETION) {
            deleted++;
          }
        }
      }
    }
    git_diff_patch_free(patch);

    CefRefPtr<CefV8Value> result = CefV8Value::CreateObject(NULL);
    result->SetValue("added", CefV8Value::CreateInt(added), V8_PROPERTY_ATTRIBUTE_NONE);
    result->SetValue("deleted", CefV8Value::CreateInt(deleted), V8_PROPERTY_ATTRIBUTE_NONE);
    return result;
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
  if (name == "getRepository") {
    CefRefPtr<CefBase> userData = new GitRepository(arguments[0]->GetStringValue().ToString().c_str());
    retval = CefV8Value::CreateObject(NULL);
    retval->SetUserData(userData);
    return true;
  }

  if (name == "getHead") {
    GitRepository *userData = (GitRepository *)object->GetUserData().get();
    retval = userData->GetHead();
    return true;
  }

  if (name == "getPath") {
    GitRepository *userData = (GitRepository *)object->GetUserData().get();
    retval = userData->GetPath();
    return true;
  }

  if (name == "isIgnored") {
    GitRepository *userData = (GitRepository *)object->GetUserData().get();
    retval = userData->IsIgnored(arguments[0]->GetStringValue().ToString().c_str());
    return true;
  }

  if (name == "getStatus") {
    GitRepository *userData = (GitRepository *)object->GetUserData().get();
    retval = userData->GetStatus(arguments[0]->GetStringValue().ToString().c_str());
    return true;
  }

  if (name == "checkoutHead") {
    GitRepository *userData = (GitRepository *)object->GetUserData().get();
    retval = userData->CheckoutHead(arguments[0]->GetStringValue().ToString().c_str());
    return true;
  }

  if (name == "getDiffStats") {
    GitRepository *userData = (GitRepository *)object->GetUserData().get();
    retval = userData->GetDiffStats(arguments[0]->GetStringValue().ToString().c_str());
    return true;
  }

  return false;
}

}
