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

    @bindCommandModeKeys
      'i': 'insert'
      'x': 'delete-char'
      'h': 'move-left'
      'j': 'move-up'

    @handleCommands
      'insert': => @activateInsertMode()
      'delete-char': => new op.DeleteChar
      'move-left': => new op.MoveLeft
      'move-up': => new op.MoveUp

    for i in [0..9]
      do (i) =>
        @registerCommand i, "numeric-prefix-#{i}", => new op.NumericPrefix(i)

  bindCommandModeKeys: (bindings) ->
    prefixedBindings = {}
    for pattern, commandName of bindings
      prefixedBindings[pattern] = "command-mode:#{commandName}"

    atom.bindKeys ".command-mode", prefixedBindings

  handleCommands: (commands) ->
    _.each commands, (fn, commandName) =>
      eventName = "command-mode:#{commandName}"
      @editor.on eventName, =>
        possibleOperator = fn()
        @pushOperator(possibleOperator) if possibleOperator.execute?

  registerCommand: (binding, commandName, fn)->
    eventName = "command-mode:#{commandName}"
    atom.bindKey '.command-mode', binding, eventName
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

