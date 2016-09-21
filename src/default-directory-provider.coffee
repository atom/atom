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
    normalizedPath = path.normalize(uri)
    {host} = url.parse(uri)
    directoryPath = if host
      uri
    else if not fs.isDirectorySync(normalizedPath) and fs.isDirectorySync(path.dirname(normalizedPath))
      path.dirname(normalizedPath)
    else
      normalizedPath

    # TODO: Stop normalizing the path in pathwatcher's Directory.
    directory = new Directory(directoryPath)
    if host
      directory.path = directoryPath
      if fs.isCaseInsensitive()
        directory.lowerCasePath = directoryPath.toLowerCase()
    directory

  # Public: Create a Directory that corresponds to the specified URI.
  #
  # * `uri` {String} The path to the directory to add. This is guaranteed not to
  # be contained by a {Directory} in `atom.project`.
  #
  # Returns a {Promise} that resolves to:
  # * {Directory} if the given URI is compatible with this provider.
  # * `null` if the given URI is not compatibile with this provider.
  directoryForURI: (uri) ->
    Promise.resolve(@directoryForURISync(uri))
