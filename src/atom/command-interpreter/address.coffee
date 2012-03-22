module.exports =
class Address
  execute: (editor) ->
    editor.getSelection().setBufferRange(@getRange(editor))
