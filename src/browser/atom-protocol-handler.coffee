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
#   * ~/.atom/dev/packages
#   * ~/.atom/packages
#   * RESOURCE_PATH/node_modules
#
module.exports =
class AtomProtocolHandler
  constructor: (@resourcePath) ->
    @loadPaths = [
      path.join(app.getHomeDir(), '.atom', 'dev', 'packages')
      path.join(app.getHomeDir(), '.atom', 'packages')
      path.join(@resourcePath, 'node_modules')
    ]

    @registerAtomProtocol()

  # Creates the 'atom' custom protocol handler.
  registerAtomProtocol: ->
    protocol.registerProtocol 'atom', (request) =>
      relativePath = path.normalize(request.url.substr(7))

      if relativePath.indexOf('assets/') is 0
        assetsPath = path.join(app.getHomeDir(), '.atom', relativePath)
        if fs.statSyncNoException(assetsPath).isFile?()
          filePath = assetsPath

      unless filePath
        for loadPath in @loadPaths
          filePath = path.join(loadPath, relativePath)
          break if fs.statSyncNoException(filePath).isFile?()

      new protocol.RequestFileJob(filePath)
