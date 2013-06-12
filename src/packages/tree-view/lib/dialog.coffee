{View} = require 'space-pen'
Editor = require 'editor'
fsUtils = require 'fs-utils'
path = require 'path'
$ = require 'jquery'

module.exports =
class Dialog extends View
  @content: ({prompt} = {}) ->
    @div class: 'tree-view-dialog', =>
      @div outlet: 'prompt', class: 'prompt', =>
        @span prompt, outlet: 'promptText'
      @subview 'miniEditor', new Editor(mini: true)

  initialize: ({initialPath, @onConfirm, select, iconClass} = {}) ->
    @prompt.addClass(iconClass) if iconClass
    @miniEditor.focus()
    @on 'core:confirm', => @onConfirm(@miniEditor.getText())
    @on 'core:cancel', => @cancel()
    @miniEditor.on 'focusout', => @remove()

    @miniEditor.setText(initialPath)

    if select
      extension = fsUtils.extension(initialPath)
      baseName = path.basename(initialPath)
      if baseName is extension
        selectionEnd = initialPath.length
      else
        selectionEnd = initialPath.length - extension.length
      range = [[0, initialPath.length - baseName.length], [0, selectionEnd]]
      @miniEditor.setSelectedBufferRange(range)

  close: ->
    @remove()
    rootView.focus()

  cancel: ->
    @remove()
    $('.tree-view').focus()

  showError: (message) ->
    @promptText.text(message)
    @flashError()
