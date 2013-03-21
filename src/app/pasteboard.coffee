crypto = require 'crypto'

module.exports =
class Pasteboard
  signatureForMetadata: null

  md5: (text) ->
    crypto.createHash('md5').update(text, 'utf8').digest('hex')

  write: (text, metadata) ->
    @signatureForMetadata = @md5(text)
    @metadata = metadata
    $native.writeToPasteboard(text)

  read: ->
    text = $native.readFromPasteboard()
    value = [text]
    value.push(@metadata) if @signatureForMetadata == @md5(text)
    value
