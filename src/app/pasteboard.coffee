{hex_md5} = require 'md5'

module.exports =
class Pasteboard
  signatureForMetadata: null

  write: (text, metadata) ->
    @signatureForMetadata = hex_md5(text)
    @metadata = metadata
    $native.writeToPasteboard(text)

  read: ->
    text = $native.readFromPasteboard()
    value = [text]
    value.push(@metadata) if @signatureForMetadata == hex_md5(text)
    value
