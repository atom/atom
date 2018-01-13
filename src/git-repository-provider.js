const fs = require('fs');
const { Directory } = require('pathwatcher');
const GitRepository = require('./git-repository');

// Returns the .gitdir path in the agnostic Git symlink .git file given, or
// null if the path is not a valid gitfile.
//
// * `gitFile` {String} path of gitfile to parse
const gitFileRegex = RegExp('^gitdir: (.+)');
function pathFromGitFile(gitFile) {
  try {
    const gitFileBuff = fs.readFileSync(gitFile, 'utf8');
    return gitFileBuff != null ? gitFileBuff.match(gitFileRegex)[1] : undefined;
  } catch (error) {}
}

// Checks whether a valid `.git` directory is contained within the given
// directory or one of its ancestors. If so, a Directory that corresponds to the
// `.git` folder will be returned. Otherwise, returns `null`.
//
// * `directory` {Directory} to explore whether it is part of a Git repository.
function findGitDirectorySync(directory) {
  // TODO: Fix node-pathwatcher/src/directory.coffee so the following methods
  // can return cached values rather than always returning new objects:
  // getParent(), getFile(), getSubdirectory().
  let gitDir = directory.getSubdirectory('.git');
  const gitDirPath = pathFromGitFile(
    typeof gitDir.getPath === 'function' ? gitDir.getPath() : undefined
  );
  if (gitDirPath) {
    gitDir = new Directory(directory.resolve(gitDirPath));
  }
  if (
    (typeof gitDir.existsSync === 'function' ? gitDir.existsSync() : undefined) &&
    isValidGitDirectorySync(gitDir)
  ) {
    return gitDir;
  } else if (directory.isRoot()) {
    return null;
  } else {
    return findGitDirectorySync(directory.getParent());
  }
}

// Returns a boolean indicating whether the specified directory represents a Git
// repository.
//
// * `directory` {Directory} whose base name is `.git`.
function isValidGitDirectorySync(directory) {
  // To decide whether a directory has a valid .git folder, we use
  // the heuristic adopted by the valid_repository_path() function defined in
  // node_modules/git-utils/deps/libgit2/src/repository.c.
  return (
    directory.getSubdirectory('objects').existsSync() &&
    directory.getFile('HEAD').existsSync() &&
    directory.getSubdirectory('refs').existsSync()
  );
}

// Provider that conforms to the atom.repository-provider@0.1.0 service.
class GitRepositoryProvider {
  constructor(project, config) {
    // Keys are real paths that end in `.git`.
    // Values are the corresponding GitRepository objects.
    this.project = project;
    this.config = config;
    this.pathToRepository = {};
  }

  // Returns a {Promise} that resolves with either:
  // * {GitRepository} if the given directory has a Git repository.
  // * `null` if the given directory does not have a Git repository.
  repositoryForDirectory(directory) {
    // TODO: Currently, this method is designed to be async, but it relies on a
    // synchronous API. It should be rewritten to be truly async.
    return Promise.resolve(this.repositoryForDirectorySync(directory));
  }

  // Returns either:
  // * {GitRepository} if the given directory has a Git repository.
  // * `null` if the given directory does not have a Git repository.
  repositoryForDirectorySync(directory) {
    // Only one GitRepository should be created for each .git folder. Therefore,
    // we must check directory and its parent directories to find the nearest
    // .git folder.
    const gitDir = findGitDirectorySync(directory);
    if (!gitDir) {
      return null;
    }

    const gitDirPath = gitDir.getPath();
    let repo = this.pathToRepository[gitDirPath];
    if (!repo) {
      repo = GitRepository.open(gitDirPath, { project: this.project, config: this.config });
      if (!repo) {
        return null;
      }
      repo.onDidDestroy(() => delete this.pathToRepository[gitDirPath]);
      this.pathToRepository[gitDirPath] = repo;
      repo.refreshIndex();
      repo.refreshStatus();
    }
    return repo;
  }
}

module.exports = GitRepositoryProvider;
