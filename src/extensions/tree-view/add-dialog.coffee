{View, $$} = require 'space-pen'
Editor = require 'editor'
fs = require 'fs'
$ = require 'jquery'

module.exports =
class AddDialog extends View
  miniEditor: null
  rootView: null
  path: null

  @content: ->
    @div class: 'add-dialog', =>
      @div "Enter the path for the new file/dir. Dirs end with '/':", outlet: 'prompt'
      @subview 'miniEditor', new Editor(mini: true)

  initialize: (@rootView, @path) ->
    @miniEditor.focus()
    @on 'tree-view:confirm', => @confirm()
    @on 'tree-view:cancel', => @cancel()
    @miniEditor.on 'focusout', => @remove()

    directoryPath = if fs.isFile(@path) then fs.directory(@path) else @path
    relativePath = @rootView.project.relativize(directoryPath) + '/'
    @miniEditor.setText(relativePath)

  confirm: ->
    relativePath = @miniEditor.getText()
    endsWithDirectorySeperator = /\/$/.test(relativePath)
    path = @rootView.project.resolve(relativePath)

    if endsWithDirectorySeperator
      fs.makeDirectory(path)
    else
      fs.write(path, "")
      @rootView.open(path)

    @remove()
    $('#root-view').focus()

  cancel: ->
    @remove()
    $('.tree-view').focus()