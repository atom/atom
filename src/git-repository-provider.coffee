fs = require 'fs'
GitRepository = require './git-repository'

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
  if directoryExistsSync(gitDir) and isValidGitDirectorySync gitDir
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
  return directoryExistsSync(directory.getSubdirectory('objects')) and
      directory.getFile('HEAD').exists() and
      directoryExistsSync(directory.getSubdirectory('refs'))

# Returns a boolean indicating whether the specified directory exists.
#
# * `directory` {Directory} to check for existence.
directoryExistsSync = (directory) ->
  # TODO: Directory should have its own existsSync() method. Currently, File has
  # an exists() method, which is synchronous, so it may be tricky to achieve
  # consistency between the File and Directory APIs. Once Directory has its own
  # method, this function should be replaced with direct calls to existsSync().
  return fs.existsSync(directory.getRealPathSync())

# Provider that conforms to the atom.repository-provider@0.1.0 service.
module.exports =
class GitRepositoryProvider

  constructor: (@project) ->
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

    gitDirPath = gitDir.getRealPathSync()
    repo = @pathToRepository[gitDirPath]
    unless repo
      repo = GitRepository.open(gitDirPath, project: @project)
      repo.onDidDestroy(() => delete @pathToRepository[gitDirPath])
      @pathToRepository[gitDirPath] = repo
      repo.refreshIndex()
      repo.refreshStatus()
    repo
