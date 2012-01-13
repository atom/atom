_ = require 'underscore'
$ = require 'jquery'
{ NumericPrefix, DeleteChar, MoveLeft, MoveUp} = require 'vim-mode-operators'

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
    @editor.on 'command-mode:delete-char', => @pushOperator(new DeleteChar)
    @editor.on 'command-mode:numeric-prefix', (e) => @pushOperator(new NumericPrefix(e.keyEvent.char))
    @editor.on 'command-mode:move-left', => @pushOperator(new MoveLeft)
    @editor.on 'command-mode:move-up', => @pushOperator(new MoveUp)

  registerCommand: (name, handler) ->
    @editor.on "command-mode:#{name}", handler

  activateInsertMode: ->
    @editor.removeClass('command-mode')
    @editor.addClass('insert-mode')

  activateCommandMode: ->
    @editor.removeClass('insert-mode')
    @editor.addClass('command-mode')

  commandModeBindings: ->
    bindings =
      'i': 'insert-mode:activate'
      'x': 'command-mode:delete-char'
      'h': 'command-mode:move-left'
      'j': 'command-mode:move-up'
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

