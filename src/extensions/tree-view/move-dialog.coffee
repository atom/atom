{View, $$} = require 'space-pen'
Editor = require 'editor'
fs = require 'fs'
$ = require 'jquery'

module.exports =
class MoveDialog extends View
  @content: ->
    @div class: 'move-dialog', =>
      @div "Enter the new path for the file:", outlet: 'prompt'
      @subview 'editor', new Editor(mini: true)

  initialize: (@project, @path) ->
    @editor.focus()
    @on 'tree-view:confirm', => @confirm()
    @on 'tree-view:cancel', => @cancel()
    @editor.on 'focusout', => @remove()

    relativePath = @project.relativize(@path)
    @editor.setText(relativePath)

    extension = fs.extension(path)
    baseName = fs.base(path)
    range = [[0, relativePath.length - baseName.length], [0, relativePath.length - extension.length]]
    @editor.setSelectionBufferRange(range)

  confirm: ->
    fs.move(@path, @project.resolve(@editor.getText()))
    @remove()
    $('#root-view').focus()

  cancel: ->
    @remove()
    $('.tree-view').focus()