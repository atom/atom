clipboard = require 'clipboard'
crypto = require 'crypto'

# Public: Represents the clipboard used for copying and pasting in Atom.
#
# A clipboard instance is always available under the `atom.clipboard` global.
module.exports =
class Clipboard
  metadata: null
  signatureForMetadata: null

  # Creates an `md5` hash of some text.
  #
  # text - A {String} to encrypt.
  #
  # Returns an encrypted {String}.
  md5: (text) ->
    crypto.createHash('md5').update(text, 'utf8').digest('hex')

  # Public: Write the given text to the clipboard.
  #
  # text - A {String} to store.
  # metadata - An {Object} of additional info to associate with the text.
  write: (text, metadata) ->
    @signatureForMetadata = @md5(text)
    @metadata = metadata
    clipboard.writeText(text)

  # Public: Read the text from the clipboard.
  #
  # Returns an {Object} with a `text` key and a `metadata` key if it has
  # associated metadata.
  read: ->
    text = clipboard.readText()
    #TODO Return object once packages have been updated.
    contents = [text]
    contents.text = text
    if @signatureForMetadata is @md5(text)
      contents.push(@metadata)
      contents.metadata = @metadata
    contents
