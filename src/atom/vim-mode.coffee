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
      'j': 'move-up'
      'w': 'move-to-next-word'

    @handleCommands
      'insert': => @activateInsertMode()
      'delete': => @delete()
      'delete-char': => new op.DeleteChar
      'move-left': => new op.MoveLeft
      'move-up': => new op.MoveUp
      'move-to-next-word': => new op.MoveToNextWord
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
    if @topOperator() instanceof op.NumericPrefix
      @topOperator().addDigit(num)
    else
      @pushOperator(new op.NumericPrefix(num))

  delete: () ->
    if @topOperator() instanceof op.Delete
      @pushOperator(new op.SelectLine)
    else
      @pushOperator(new op.Delete)

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

