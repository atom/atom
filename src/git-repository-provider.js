const fs = require('fs');
const { Directory } = require('pathwatcher');
const GitRepository = require('./git-repository');

const GIT_FILE_REGEX = RegExp('^gitdir: (.+)');

// Returns the .gitdir path in the agnostic Git symlink .git file given, or
// null if the path is not a valid gitfile.
//
// * `gitFile` {String} path of gitfile to parse
function pathFromGitFileSync(gitFile) {
  try {
    const gitFileBuff = fs.readFileSync(gitFile, 'utf8');
    return gitFileBuff != null ? gitFileBuff.match(GIT_FILE_REGEX)[1] : null;
  } catch (error) {}
}

// Returns a {Promise} that resolves to the .gitdir path in the agnostic
// Git symlink .git file given, or null if the path is not a valid gitfile.
//
// * `gitFile` {String} path of gitfile to parse
function pathFromGitFile(gitFile) {
  return new Promise(resolve => {
    fs.readFile(gitFile, 'utf8', (err, gitFileBuff) => {
      if (err == null && gitFileBuff != null) {
        const result = gitFileBuff.toString().match(GIT_FILE_REGEX);
        resolve(result != null ? result[1] : null);
      } else {
        resolve(null);
      }
    });
  });
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
  if (typeof gitDir.getPath === 'function') {
    const gitDirPath = pathFromGitFileSync(gitDir.getPath());
    if (gitDirPath) {
      gitDir = new Directory(directory.resolve(gitDirPath));
    }
  }
  if (
    typeof gitDir.existsSync === 'function' &&
    gitDir.existsSync() &&
    isValidGitDirectorySync(gitDir)
  ) {
    return gitDir;
  } else if (directory.isRoot()) {
    return null;
  } else {
    return findGitDirectorySync(directory.getParent());
  }
}

// Checks whether a valid `.git` directory is contained within the given
// directory or one of its ancestors. If so, a Directory that corresponds to the
// `.git` folder will be returned. Otherwise, returns `null`.
//
// Returns a {Promise} that resolves to
// * `directory` {Directory} to explore whether it is part of a Git repository.
async function findGitDirectory(directory) {
  // TODO: Fix node-pathwatcher/src/directory.coffee so the following methods
  // can return cached values rather than always returning new objects:
  // getParent(), getFile(), getSubdirectory().
  let gitDir = directory.getSubdirectory('.git');
  if (typeof gitDir.getPath === 'function') {
    const gitDirPath = await pathFromGitFile(gitDir.getPath());
    if (gitDirPath) {
      gitDir = new Directory(directory.resolve(gitDirPath));
    }
  }
  if (
    typeof gitDir.exists === 'function' &&
    (await gitDir.exists()) &&
    (await isValidGitDirectory(gitDir))
  ) {
    return gitDir;
  } else if (directory.isRoot()) {
    return null;
  } else {
    return findGitDirectory(directory.getParent());
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
  const commonDirFile = directory.getSubdirectory('commondir');
  let commonDir;
  if (commonDirFile.existsSync()) {
    const commonDirPathBuff = fs.readFileSync(commonDirFile.getPath());
    const commonDirPathString = commonDirPathBuff.toString().trim();
    commonDir = new Directory(directory.resolve(commonDirPathString));
    if (!commonDir.existsSync()) {
      return false;
    }
  } else {
    commonDir = directory;
  }
  return (
    directory.getFile('HEAD').existsSync() &&
    commonDir.getSubdirectory('objects').existsSync() &&
    commonDir.getSubdirectory('refs').existsSync()
  );
}

// Returns a {Promise} that resolves to a {Boolean} indicating whether the
// specified directory represents a Git repository.
//
// * `directory` {Directory} whose base name is `.git`.
async function isValidGitDirectory(directory) {
  // To decide whether a directory has a valid .git folder, we use
  // the heuristic adopted by the valid_repository_path() function defined in
  // node_modules/git-utils/deps/libgit2/src/repository.c.
  const commonDirFile = directory.getSubdirectory('commondir');
  let commonDir;
  if (await commonDirFile.exists()) {
    const commonDirPathBuff = await fs.readFile(commonDirFile.getPath());
    const commonDirPathString = commonDirPathBuff.toString().trim();
    commonDir = new Directory(directory.resolve(commonDirPathString));
    if (!(await commonDir.exists())) {
      return false;
    }
  } else {
    commonDir = directory;
  }
  return (
    (await directory.getFile('HEAD').exists()) &&
    (await commonDir.getSubdirectory('objects').exists()) &&
    commonDir.getSubdirectory('refs').exists()
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
  async repositoryForDirectory(directory) {
    // Only one GitRepository should be created for each .git folder. Therefore,
    // we must check directory and its parent directories to find the nearest
    // .git folder.
    const gitDir = await findGitDirectory(directory);
    return this.repositoryForGitDirectory(gitDir);
  }

  // Returns either:
  // * {GitRepository} if the given directory has a Git repository.
  // * `null` if the given directory does not have a Git repository.
  repositoryForDirectorySync(directory) {
    // Only one GitRepository should be created for each .git folder. Therefore,
    // we must check directory and its parent directories to find the nearest
    // .git folder.
    const gitDir = findGitDirectorySync(directory);
    return this.repositoryForGitDirectory(gitDir);
  }

  // Returns either:
  // * {GitRepository} if the given Git directory has a Git repository.
  // * `null` if the given directory does not have a Git repository.
  repositoryForGitDirectory(gitDir) {
    if (!gitDir) {
      return null;
    }

    const gitDirPath = gitDir.getPath();
    let repo = this.pathToRepository[gitDirPath];
    if (!repo) {
      repo = GitRepository.open(gitDirPath, {
        project: this.project,
        config: this.config
      });
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
