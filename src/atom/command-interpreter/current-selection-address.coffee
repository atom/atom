Address = require 'command-interpreter/address'
Range = require 'range'

module.exports =
class CurrentSelectionAddress extends Address
  getRange: (editor) ->
    editor.getSelection().getBufferRange()

  isRelative: -> true
