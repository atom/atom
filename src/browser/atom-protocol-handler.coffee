app = require 'app'
fs = require 'fs'
path = require 'path'
protocol = require 'protocol'

# Handles requests with 'atom' protocol.
#
# It's created by {AtomApplication} upon instantiation and is used to create a
# custom resource loader for 'atom://' URLs.
#
# The following directories are searched in order:
#   * ~/.atom/assets
#   * ~/.atom/dev/packages (unless in safe mode)
#   * ~/.atom/packages
#   * RESOURCE_PATH/node_modules
#
module.exports =
class AtomProtocolHandler
  constructor: (resourcePath, safeMode) ->
    @loadPaths = []

    unless safeMode
      @loadPaths.push(path.join(process.env.ATOM_HOME, 'dev', 'packages'))

    @loadPaths.push(path.join(process.env.ATOM_HOME, 'packages'))
    @loadPaths.push(path.join(resourcePath, 'node_modules'))

    @registerAtomProtocol()

  # Creates the 'atom' custom protocol handler.
  registerAtomProtocol: ->
    protocol.registerFileProtocol 'atom', (request, callback) =>
      relativePath = path.normalize(request.url.substr(7))

      if relativePath.indexOf('assets/') is 0
        assetsPath = path.join(process.env.ATOM_HOME, relativePath)
        filePath = assetsPath if fs.statSyncNoException(assetsPath).isFile?()

      unless filePath
        for loadPath in @loadPaths
          filePath = path.join(loadPath, relativePath)
          break if fs.statSyncNoException(filePath).isFile?()

      callback(filePath)
