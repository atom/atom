_ = require 'underscore'
$ = require 'jquery'
op = require 'vim-mode-operators'

module.exports =
class VimMode
  editor: null
  opStack: null

  constructor: (@editor) ->
    @opStack = []
    @editor.addClass('command-mode')

    atom.bindKeys '.editor', '<esc>': 'activate-command-mode'
    @editor.on 'activate-command-mode', => @activateCommandMode()

    @setupCommandMode()

  setupCommandMode: ->
    atom.bindKeys '.command-mode', -> false

    @registerCommand 'i', 'insert', => @activateInsertMode()
    @registerCommand 'x', 'delete-char', => new op.DeleteChar
    @registerCommand 'h', 'move-left', => new op.MoveLeft
    @registerCommand 'j', 'move-up', => new op.MoveUp

    for i in [0..9]
      do (i) =>
        @registerCommand i, "numeric-prefix-#{i}", => new op.NumericPrefix(i)

  registerCommand: (binding, commandName, fn)->
    bindings = {}
    eventName = "command-mode:#{commandName}"
    bindings[binding] = eventName
    atom.bindKeys '.command-mode', bindings
    @editor.on eventName, =>
      possibleOperator = fn()
      @pushOperator(possibleOperator) if possibleOperator.execute?

  activateInsertMode: ->
    @editor.removeClass('command-mode')
    @editor.addClass('insert-mode')

  activateCommandMode: ->
    @editor.removeClass('insert-mode')
    @editor.addClass('command-mode')

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

