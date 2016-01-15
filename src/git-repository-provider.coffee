fs = require 'fs'
{Directory} = require 'pathwatcher'
GitRepository = require './git-repository'

# Returns the .gitdir path in the agnostic Git symlink .git file given, or
# null if the path is not a valid gitfile.
#
# * `gitFile` {String} path of gitfile to parse
gitFileRegex = RegExp "^gitdir: (.+)"
pathFromGitFile = (gitFile) ->
  try
    gitFileBuff = fs.readFileSync(gitFile, 'utf8')
    return gitFileBuff?.match(gitFileRegex)[1]

# Checks whether a valid `.git` directory is contained within the given
# directory or one of its ancestors. If so, a Directory that corresponds to the
# `.git` folder will be returned. Otherwise, returns `null`.
#
# * `directory` {Directory} to explore whether it is part of a Git repository.
findGitDirectorySync = (directory) ->
  # TODO: Fix node-pathwatcher/src/directory.coffee so the following methods
  # can return cached values rather than always returning new objects:
  # getParent(), getFile(), getSubdirectory().
  gitDir = directory.getSubdirectory('.git')
  gitDirPath = pathFromGitFile(gitDir.getPath?())
  if gitDirPath
    gitDir = new Directory(directory.resolve(gitDirPath))
  if gitDir.existsSync?() and isValidGitDirectorySync gitDir
    gitDir
  else if directory.isRoot()
    return null
  else
    findGitDirectorySync directory.getParent()

# Returns a boolean indicating whether the specified directory represents a Git
# repository.
#
# * `directory` {Directory} whose base name is `.git`.
isValidGitDirectorySync = (directory) ->
  # To decide whether a directory has a valid .git folder, we use
  # the heuristic adopted by the valid_repository_path() function defined in
  # node_modules/git-utils/deps/libgit2/src/repository.c.
  return directory.getSubdirectory('objects').existsSync() and
      directory.getFile('HEAD').existsSync() and
      directory.getSubdirectory('refs').existsSync()

# Provider that conforms to the atom.repository-provider@0.1.0 service.
module.exports =
class GitRepositoryProvider

  constructor: (@project, @config) ->
    # Keys are real paths that end in `.git`.
    # Values are the corresponding GitRepository objects.
    @pathToRepository = {}

  # Returns a {Promise} that resolves with either:
  # * {GitRepository} if the given directory has a Git repository.
  # * `null` if the given directory does not have a Git repository.
  repositoryForDirectory: (directory) ->
    # TODO: Currently, this method is designed to be async, but it relies on a
    # synchronous API. It should be rewritten to be truly async.
    Promise.resolve(@repositoryForDirectorySync(directory))

  # Returns either:
  # * {GitRepository} if the given directory has a Git repository.
  # * `null` if the given directory does not have a Git repository.
  repositoryForDirectorySync: (directory) ->
    # Only one GitRepository should be created for each .git folder. Therefore,
    # we must check directory and its parent directories to find the nearest
    # .git folder.
    gitDir = findGitDirectorySync(directory)
    unless gitDir
      return null

    gitDirPath = gitDir.getPath()
    repo = @pathToRepository[gitDirPath]
    unless repo
      repo = GitRepository.open(gitDirPath, {@project, @config})
      return null unless repo
      repo.async.onDidDestroy(=> delete @pathToRepository[gitDirPath])
      @pathToRepository[gitDirPath] = repo
      repo.refreshIndex()
      repo.refreshStatus()
    repo
