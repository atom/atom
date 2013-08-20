clipboard = require 'clipboard'
crypto = require 'crypto'

# Internal: Represents the clipboard used for copying and pasting in Atom.
module.exports =
class Pasteboard
  signatureForMetadata: null

  # Creates an `md5` hash of some text.
  #
  # text - A {String} to encrypt.
  #
  # Returns an encrypted {String}.
  md5: (text) ->
    crypto.createHash('md5').update(text, 'utf8').digest('hex')

  # Saves from the clipboard.
  #
  # text - A {String} to store
  # metadata - An object of additional info to associate with the text
  write: (text, metadata) ->
    @signatureForMetadata = @md5(text)
    @metadata = metadata
    clipboard.writeText(text)

  # Loads from the clipboard.
  #
  # Returns an {Array}. The first index is the saved text, and the second is any metadata associated with the text.
  read: ->
    text = clipboard.readText()
    value = [text]
    value.push(@metadata) if @signatureForMetadata == @md5(text)
    value
