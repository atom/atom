path = require 'path'
protocol = require 'protocol'

# Private: Handles requests with 'atom' protocol.
#
# It's created by {AtomApplication} upon instantiation, and is used to create a
# custom resource loader by adding the 'atom' custom protocol.
module.exports =
class AtomProtocolHandler
  constructor: (@resourcePath) ->
    @registerAtomProtocol()

  # Private: Creates the 'atom' custom protocol handler.
  registerAtomProtocol: ->
    protocol.registerProtocol 'atom', (request) =>
      relativePath = path.normalize(request.url.substr(7))
      filePath = path.join(@resourcePath, 'node_modules', relativePath)
      return new protocol.RequestFileJob(filePath)
