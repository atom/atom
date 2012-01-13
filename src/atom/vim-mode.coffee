_ = require 'underscore'
$ = require 'jquery'
{ NumericPrefix, DeleteChar } = require 'vim-mode-operators'

module.exports =
class VimMode
  editor: null
  opStack: null

  constructor: (@editor) ->
    @opStack = []
    atom.bindKeys '.command-mode', -> false
    atom.bindKeys '.command-mode', @commandModeBindings()
    atom.bindKeys '.insert-mode', '<esc>': 'command-mode:activate'

    @editor.addClass('command-mode')

    @editor.on 'insert-mode:activate', => @activateInsertMode()
    @editor.on 'command-mode:activate', => @activateCommandMode()
    @editor.on 'command-mode:delete-char', => @deleteChar()
    @editor.on 'command-mode:numeric-prefix', (e) => @numericPrefix(e)

  activateInsertMode: ->
    @editor.removeClass('command-mode')
    @editor.addClass('insert-mode')

  activateCommandMode: ->
    @editor.removeClass('insert-mode')
    @editor.addClass('command-mode')

  deleteChar: ->
    @pushOperator(new DeleteChar)

  numericPrefix: (e) ->
    @pushOperator(new NumericPrefix(e.keyEvent.char))

  commandModeBindings: ->
    bindings =
      'i': 'insert-mode:activate'
      'x': 'command-mode:delete-char'
    for i in [0..9]
      bindings[i] = 'command-mode:numeric-prefix'
    bindings

  pushOperator: (op) ->
    @opStack.push(op)
    @processOpStack()

  processOpStack: ->
    return unless @topOperator().isComplete()
    poppedOperator = @opStack.pop()
    if @opStack.length
      @topOperator().compose(poppedOperator)
      @processOpStack()
    else
      poppedOperator.execute(@editor)

  topOperator: ->
    _.last @opStack

