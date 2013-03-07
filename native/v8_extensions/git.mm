#import "git.h"
#import "include/git2.h"
#import <Cocoa/Cocoa.h>

namespace v8_extensions {

  class GitRepository : public CefBase {
  private:
    git_repository *repo;

    static int CollectStatus(const char *path, unsigned int status, void *payload) {
      if ((status & GIT_STATUS_IGNORED) == 0) {
        std::map<const char*, unsigned int> *statuses = (std::map<const char*, unsigned int> *) payload;
        statuses->insert(std::pair<const char*, unsigned int>(path, status));
      }
      return 0;
    }

    static int CollectDiffHunk(const git_diff_delta *delta, const git_diff_range *range,
                               const char *header, size_t header_len, void *payload) {
      std::vector<git_diff_range> *ranges = (std::vector<git_diff_range> *) payload;
      ranges->push_back(*range);
      return 0;
    }

  public:
    GitRepository(const char *pathInRepo) {
      if (git_repository_open_ext(&repo, pathInRepo, 0, NULL) != GIT_OK) {
        repo = NULL;
      }
    }

    ~GitRepository() {
      Destroy();
    }

    void Destroy() {
      if (Exists()) {
        git_repository_free(repo);
        repo = NULL;
      }
    }

    BOOL Exists() {
      return repo != NULL;
    }

    CefRefPtr<CefV8Value> GetPath() {
      return CefV8Value::CreateString(git_repository_path(repo));
    }

    CefRefPtr<CefV8Value> GetHead() {
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

    CefRefPtr<CefV8Value> GetStatuses() {
      std::map<const char*, unsigned int> statuses;
      git_status_foreach(repo, CollectStatus, &statuses);
      std::map<const char*, unsigned int>::iterator iter = statuses.begin();
      CefRefPtr<CefV8Value> v8Statuses = CefV8Value::CreateObject(NULL);
      for (; iter != statuses.end(); ++iter) {
        v8Statuses->SetValue(iter->first, CefV8Value::CreateInt(iter->second), V8_PROPERTY_ATTRIBUTE_NONE);
      }
      return v8Statuses;
    }

    int GetCommitCount(const git_oid* fromCommit, const git_oid* toCommit) {
      int count = 0;
      git_revwalk *revWalk;
      if (git_revwalk_new(&revWalk, repo) == GIT_OK) {
        git_revwalk_push(revWalk, fromCommit);
        git_revwalk_hide(revWalk, toCommit);
        git_oid currentCommit;
        while (git_revwalk_next(&currentCommit, revWalk) == GIT_OK)
          count++;
        git_revwalk_free(revWalk);
      }
      return count;
    }

    void GetShortBranchName(const char** out, const char* branchName) {
      *out = NULL;
      if (branchName == NULL)
        return;
      int branchNameLength = strlen(branchName);
      if (branchNameLength < 12)
        return;
      if (strncmp("refs/heads/", branchName, 11) != 0)
        return;

      int shortNameLength = branchNameLength - 11;
      char* shortName = (char*) malloc(sizeof(char) * (shortNameLength + 1));
      shortName[shortNameLength] = '\0';
      strncpy(shortName, &branchName[11], shortNameLength);
      *out = shortName;
    }

    void GetUpstreamBranch(const char** out, git_reference *branch) {
      *out = NULL;

      const char* branchName = git_reference_name(branch);
      const char* shortBranchName;
      GetShortBranchName(&shortBranchName, branchName);
      if (shortBranchName == NULL)
        return;

      int shortBranchNameLength = strlen(shortBranchName);
      char* remoteKey = (char*) malloc(sizeof(char) * (shortBranchNameLength + 15));
      sprintf(remoteKey, "branch.%s.remote", shortBranchName);
      char* mergeKey = (char*) malloc(sizeof(char) * (shortBranchNameLength + 14));
      sprintf(mergeKey, "branch.%s.merge", shortBranchName);
      free((char*)shortBranchName);

      git_config *config;
      if (git_repository_config(&config, repo) != GIT_OK) {
        free(remoteKey);
        free(mergeKey);
        return;
      }

      const char *remote;
      const char *merge;
      if (git_config_get_string(&remote, config, remoteKey) == GIT_OK
          && git_config_get_string(&merge, config, mergeKey) == GIT_OK) {
        int remoteLength = strlen(remote);
        if (remoteLength > 0) {
          const char *shortMergeBranchName;
          GetShortBranchName(&shortMergeBranchName, merge);
          if (shortMergeBranchName != NULL) {
            int updateBranchLength = remoteLength + strlen(shortMergeBranchName) + 14;
            char* upstreamBranch = (char*) malloc(sizeof(char) * (updateBranchLength + 1));
            sprintf(upstreamBranch, "refs/remotes/%s/%s", remote, shortMergeBranchName);
            *out = upstreamBranch;
          }
          free((char*)shortMergeBranchName);
        }
      }

      free(remoteKey);
      free(mergeKey);
      git_config_free(config);
    }

    CefRefPtr<CefV8Value> GetAheadBehindCounts() {
      CefRefPtr<CefV8Value> result = NULL;
      git_reference *head;
      if (git_repository_head(&head, repo) == GIT_OK) {
        const char* upstreamBranchName;
        GetUpstreamBranch(&upstreamBranchName, head);
        if (upstreamBranchName != NULL) {
          git_reference *upstream;
          if (git_reference_lookup(&upstream, repo, upstreamBranchName) == GIT_OK) {
            const git_oid* headSha = git_reference_target(head);
            const git_oid* upstreamSha = git_reference_target(upstream);
            git_oid mergeBase;
            if (git_merge_base(&mergeBase, repo, headSha, upstreamSha) == GIT_OK) {
              result = CefV8Value::CreateObject(NULL);
              int ahead = GetCommitCount(headSha, &mergeBase);
              result->SetValue("ahead", CefV8Value::CreateInt(ahead), V8_PROPERTY_ATTRIBUTE_NONE);
              int behind = GetCommitCount(upstreamSha, &mergeBase);
              result->SetValue("behind", CefV8Value::CreateInt(behind), V8_PROPERTY_ATTRIBUTE_NONE);
            }
            git_reference_free(upstream);
          }
          free((char*)upstreamBranchName);
        }
        git_reference_free(head);
      }

      if (result != NULL)
        return result;
      else
        return CefV8Value::CreateNull();
    }

    CefRefPtr<CefV8Value> IsIgnored(const char *path) {
      int ignored;
      if (git_ignore_path_is_ignored(&ignored, repo, path) == GIT_OK) {
        return CefV8Value::CreateBool(ignored == 1);
      }
      else {
        return CefV8Value::CreateBool(false);
      }
    }

    CefRefPtr<CefV8Value> GetStatus(const char *path) {
      unsigned int status = 0;
      if (git_status_file(&status, repo, path) == GIT_OK) {
        return CefV8Value::CreateInt(status);
      }
      else {
        return CefV8Value::CreateInt(0);
      }
    }

    CefRefPtr<CefV8Value> CheckoutHead(const char *path) {
      char *copiedPath = (char *)malloc(sizeof(char) * (strlen(path) + 1));
      strcpy(copiedPath, path);
      git_checkout_opts options = GIT_CHECKOUT_OPTS_INIT;
      options.checkout_strategy = GIT_CHECKOUT_FORCE;
      git_strarray paths;
      paths.count = 1;
      paths.strings = &copiedPath;
      options.paths = paths;

      int result = git_checkout_head(repo, &options);
      free(copiedPath);
      return CefV8Value::CreateBool(result == GIT_OK);
    }

    CefRefPtr<CefV8Value> GetDiffStats(const char *path) {
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
      git_tree_free(tree);
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
            switch (lineType) {
              case GIT_DIFF_LINE_ADDITION:
                added++;
                break;
              case GIT_DIFF_LINE_DELETION:
                deleted++;
                break;
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

    CefRefPtr<CefV8Value> GetLineDiffs(const char *path, const char *text) {
      git_reference *head;
      if (git_repository_head(&head, repo) != GIT_OK)
        return CefV8Value::CreateNull();

      const git_oid* sha = git_reference_target(head);
      git_commit *commit;
      int commitStatus = git_commit_lookup(&commit, repo, sha);
      git_reference_free(head);
      if (commitStatus != GIT_OK)
        return CefV8Value::CreateNull();

      git_tree *tree;
      int treeStatus = git_commit_tree(&tree, commit);
      git_commit_free(commit);
      if (treeStatus != GIT_OK)
        return CefV8Value::CreateNull();

      git_tree_entry* treeEntry;
      git_tree_entry_bypath(&treeEntry, tree, path);
      git_blob *blob = NULL;
      if (treeEntry != NULL) {
        const git_oid *blobSha = git_tree_entry_id(treeEntry);
        if (blobSha == NULL || git_blob_lookup(&blob, repo, blobSha) != GIT_OK)
          blob = NULL;
      }
      git_tree_free(tree);
      if (blob == NULL)
        return CefV8Value::CreateNull();

      int size = strlen(text);
      std::vector<git_diff_range> ranges;
      git_diff_options options = GIT_DIFF_OPTIONS_INIT;
      options.context_lines = 1;
      if (git_diff_blob_to_buffer(blob, text, size, &options, NULL, CollectDiffHunk, NULL, &ranges) == GIT_OK) {
        CefRefPtr<CefV8Value> v8Ranges = CefV8Value::CreateArray(ranges.size());
        for(int i = 0; i < ranges.size(); i++) {
          CefRefPtr<CefV8Value> v8Range = CefV8Value::CreateObject(NULL);
          v8Range->SetValue("oldStart", CefV8Value::CreateInt(ranges[i].old_start), V8_PROPERTY_ATTRIBUTE_NONE);
          v8Range->SetValue("oldLines", CefV8Value::CreateInt(ranges[i].old_lines), V8_PROPERTY_ATTRIBUTE_NONE);
          v8Range->SetValue("newStart", CefV8Value::CreateInt(ranges[i].new_start), V8_PROPERTY_ATTRIBUTE_NONE);
          v8Range->SetValue("newLines", CefV8Value::CreateInt(ranges[i].new_lines), V8_PROPERTY_ATTRIBUTE_NONE);
          v8Ranges->SetValue(i, v8Range);
        }
        git_blob_free(blob);
        return v8Ranges;
      } else {
        git_blob_free(blob);
        return CefV8Value::CreateNull();
      }
    }

    CefRefPtr<CefV8Value> IsSubmodule(const char *path) {
      BOOL isSubmodule = false;
      git_index* index;
      if (git_repository_index(&index, repo) == GIT_OK) {
        const git_index_entry *entry = git_index_get_bypath(index, path, 0);
        isSubmodule = entry != NULL && (entry->mode & S_IFMT) == GIT_FILEMODE_COMMIT;
        git_index_free(index);
      }
      return CefV8Value::CreateBool(isSubmodule);
    }

    void RefreshIndex() {
      git_index* index;
      if (git_repository_index(&index, repo) == GIT_OK) {
        git_index_read(index);
        git_index_free(index);
      }
    }

    IMPLEMENT_REFCOUNTING(GitRepository);
  };

  Git::Git() : CefV8Handler() {
    git_threads_init();
  }

  void Git::CreateContextBinding(CefRefPtr<CefV8Context> context) {
    const char* methodNames[] = {
      "getRepository", "getHead", "getPath", "isIgnored", "getStatus", "checkoutHead",
      "getDiffStats", "isSubmodule", "refreshIndex", "destroy", "getStatuses",
      "getAheadBehindCounts", "getLineDiffs"
    };

    CefRefPtr<CefV8Value> nativeObject = CefV8Value::CreateObject(NULL);
    int arrayLength = sizeof(methodNames) / sizeof(const char *);
    for (int i = 0; i < arrayLength; i++) {
      const char *functionName = methodNames[i];
      CefRefPtr<CefV8Value> function = CefV8Value::CreateFunction(functionName, this);
      nativeObject->SetValue(functionName, function, V8_PROPERTY_ATTRIBUTE_NONE);
    }

    CefRefPtr<CefV8Value> global = context->GetGlobal();
    global->SetValue("$git", nativeObject, V8_PROPERTY_ATTRIBUTE_NONE);
  }

  bool Git::Execute(const CefString& name,
                    CefRefPtr<CefV8Value> object,
                    const CefV8ValueList& arguments,
                    CefRefPtr<CefV8Value>& retval,
                    CefString& exception) {
    @autoreleasepool {
      if (name == "getRepository") {
        GitRepository *repository = new GitRepository(arguments[0]->GetStringValue().ToString().c_str());
        if (repository->Exists()) {
          CefRefPtr<CefBase> userData = repository;
          retval = CefV8Value::CreateObject(NULL);
          retval->SetUserData(userData);
        } else {
          retval = CefV8Value::CreateNull();
        }
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

      if (name == "isSubmodule") {
        GitRepository *userData = (GitRepository *)object->GetUserData().get();
        retval = userData->IsSubmodule(arguments[0]->GetStringValue().ToString().c_str());
        return true;
      }

      if (name == "refreshIndex") {
        GitRepository *userData = (GitRepository *)object->GetUserData().get();
        userData->RefreshIndex();
        return true;
      }

      if (name == "destroy") {
        GitRepository *userData = (GitRepository *)object->GetUserData().get();
        userData->Destroy();
        return true;
      }

      if (name == "getStatuses") {
        GitRepository *userData = (GitRepository *)object->GetUserData().get();
        retval = userData->GetStatuses();
        return true;
      }

      if (name == "getAheadBehindCounts") {
        GitRepository *userData = (GitRepository *)object->GetUserData().get();
        retval = userData->GetAheadBehindCounts();
        return true;
      }

      if (name == "getLineDiffs") {
        GitRepository *userData = (GitRepository *)object->GetUserData().get();
        std::string path = arguments[0]->GetStringValue().ToString();
        std::string text = arguments[1]->GetStringValue().ToString();
        retval = userData->GetLineDiffs(path.c_str(), text.c_str());
        return true;
      }

      return false;
    }
  }
}
