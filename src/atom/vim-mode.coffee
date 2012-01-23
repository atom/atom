_ = require 'underscore'
$ = require 'jquery'
operators = require 'vim-mode/operators'
commands = require 'vim-mode/commands'
motions = require 'vim-mode/motions'

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
    atom.bindKeys '.command-mode', (e) ->
      if e.keystroke.match /^\d$/
        return 'command-mode:numeric-prefix'
      if e.keystroke.match /^.$/
        return false

    @bindCommandModeKeys
      'i': 'insert'
      'd': 'delete'
      'x': 'delete-char'
      'h': 'move-left'
      'j': 'move-down'
      'k': 'move-up'
      'w': 'move-to-next-word'

    @handleCommands
      'insert': => @activateInsertMode()
      'delete': => @delete()
      'delete-char': => new commands.DeleteChar(@editor)
      'move-left': => new motions.MoveLeft(@editor)
      'move-up': => new motions.MoveUp(@editor)
      'move-down': => new motions.MoveDown @editor
      'move-to-next-word': => new motions.MoveToNextWord(@editor)
      'numeric-prefix': (e) => @numericPrefix(e)

  bindCommandModeKeys: (bindings) ->
    prefixedBindings = {}
    for pattern, commandName of bindings
      prefixedBindings[pattern] = "command-mode:#{commandName}"

    atom.bindKeys ".command-mode", prefixedBindings

  handleCommands: (commands) ->
    _.each commands, (fn, commandName) =>
      eventName = "command-mode:#{commandName}"
      @editor.on eventName, (e) =>
        possibleOperator = fn(e)
        @pushOperator(possibleOperator) if possibleOperator?.execute

  activateInsertMode: ->
    @editor.removeClass('command-mode')
    @editor.addClass('insert-mode')

  activateCommandMode: ->
    @editor.removeClass('insert-mode')
    @editor.addClass('command-mode')

  numericPrefix: (e) ->
    num = parseInt(e.keyEvent.keystroke)
    if @topOperator() instanceof operators.NumericPrefix
      @topOperator().addDigit(num)
    else
      @pushOperator(new operators.NumericPrefix(num))

  delete: () ->
    if @topOperator() instanceof operators.Delete
      @pushOperator(new motions.SelectLine(@editor))
    else
      @pushOperator(new operators.Delete(@editor))

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
      poppedOperator.execute()

  topOperator: ->
    _.last @opStack

