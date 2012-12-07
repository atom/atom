{hex_md5} = require 'md5'
gui = window.require('nw.gui')
clipboard = gui.Clipboard.get()

module.exports =
class Pasteboard
  signatureForMetadata: null

  write: (text, metadata) ->
    @signatureForMetadata = hex_md5(text)
    @metadata = metadata
    clipboard.set(text)

  read: ->
    text = clipboard.get()
    value = [text]
    value.push(@metadata) if @signatureForMetadata == hex_md5(text)
    value
