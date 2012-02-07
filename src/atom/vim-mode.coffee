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
    requireStylesheet 'vim-mode.css'

    @opStack = []
    @activateCommandMode()

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
      'x': 'delete-right'
      'h': 'move-left'
      'j': 'move-down'
      'k': 'move-up'
      'l': 'move-right'
      'w': 'move-to-next-word'
      'b': 'move-to-previous-word'
      'left': 'move-left'
      'right': 'move-right'

    @handleCommands
      'insert': => @activateInsertMode()
      'delete': => @delete()
      'delete-right': => new commands.DeleteRight(@editor)
      'move-left': => new motions.MoveLeft(@editor)
      'move-up': => new motions.MoveUp(@editor)
      'move-down': => new motions.MoveDown @editor
      'move-right': => new motions.MoveRight @editor
      'move-to-next-word': => new motions.MoveToNextWord(@editor)
      'move-to-previous-word': => new motions.MoveToPreviousWord(@editor)
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

    @editor.off 'cursor:position-changed', @moveCursorBeforeNewline

  activateCommandMode: ->
    @editor.removeClass('insert-mode')
    @editor.addClass('command-mode')

    @editor.on 'cursor:position-changed', @moveCursorBeforeNewline

  moveCursorBeforeNewline: =>
    if not @editor.selection.modifyingSelection and @editor.cursor.isOnEOL() and @editor.getCurrentLine().length > 0
      @editor.setCursorColumn(@editor.getCurrentLine().length - 1)

  numericPrefix: (e) ->
    num = parseInt(e.keyEvent.keystroke)
    if @topOperator() instanceof operators.NumericPrefix
      @topOperator().addDigit(num)
    else
      @pushOperator(new operators.NumericPrefix(num))

  delete: () ->
    if deleteOperation = @isDeletePending()
      deleteOperation.complete = true
      @processOpStack()
    else
      @pushOperator(new operators.Delete(@editor))

  isDeletePending: () ->
    for op in @opStack
      return op if op instanceof operators.Delete
    false

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
