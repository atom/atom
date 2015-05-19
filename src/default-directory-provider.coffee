{Directory} = require 'pathwatcher'
fs = require 'fs-plus'
path = require 'path'
url = require 'url'

module.exports =
class DefaultDirectoryProvider

  # Public: Create a Directory that corresponds to the specified URI.
  #
  # * `uri` {String} The path to the directory to add. This is guaranteed not to
  # be contained by a {Directory} in `atom.project`.
  #
  # Returns:
  # * {Directory} if the given URI is compatible with this provider.
  # * `null` if the given URI is not compatibile with this provider.
  directoryForURISync: (uri) ->
    projectPath = path.normalize(uri)

    directoryPath = if not fs.isDirectorySync(projectPath) and fs.isDirectorySync(path.dirname(projectPath))
      path.dirname(projectPath)
    else
      projectPath

    # TODO: Stop normalizing the path in pathwatcher's Directory.
    directory = new Directory(directoryPath)
    if (url.parse(directoryPath).protocol)
      directory.path = directoryPath;
      if (fs.isCaseInsensitive())
        directory.lowerCasePath = directoryPath.toLowerCase();
    directory

  # Public: Create a Directory that corresponds to the specified URI.
  #
  # * `uri` {String} The path to the directory to add. This is guaranteed not to
  # be contained by a {Directory} in `atom.project`.
  #
  # Returns a Promise that resolves to:
  # * {Directory} if the given URI is compatible with this provider.
  # * `null` if the given URI is not compatibile with this provider.
  directoryForURI: (uri) ->
    Promise.resolve(@directoryForURISync(uri))
