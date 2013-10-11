app = require 'app'
fs = require 'fs'
path = require 'path'
protocol = require 'protocol'

# Private: Handles requests with 'atom' protocol.
#
# It's created by {AtomApplication} upon instantiation, and is used to create a
# custom resource loader by adding the 'atom' custom protocol.
module.exports =
class AtomProtocolHandler
  constructor: (@resourcePath) ->
    @loadPaths = [
      path.join(@resourcePath, 'node_modules')
      path.join(app.getHomeDir(), '.atom', 'packages')
    ]

    @registerAtomProtocol()

  # Private: Creates the 'atom' custom protocol handler.
  registerAtomProtocol: ->
    protocol.registerProtocol 'atom', (request) =>
      relativePath = path.normalize(request.url.substr(7))
      for loadPath in @loadPaths
        filePath = path.join(loadPath, relativePath)
        break if fs.statSyncNoException(filePath)?
      return new protocol.RequestFileJob(filePath)
