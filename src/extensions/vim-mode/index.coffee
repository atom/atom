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

    window.keymap.bindKeys '.editor', 'escape': 'activate-command-mode'
    @editor.on 'activate-command-mode', => @activateCommandMode()

    @setupCommandMode()

  setupCommandMode: ->
    window.keymap.bindKeys '.command-mode', (e) =>
      if e.keystroke.match /^\d$/
        return 'command-mode:numeric-prefix'
      if e.keystroke.match /^.$/
        @resetCommandMode()
        return false

    @bindCommandModeKeys
      'i': 'insert'
      'd': 'delete'
      'x': 'delete-right'
      'h': 'core:move-left'
      'j': 'core:move-down'
      'k': 'core:move-up'
      'l': 'core:move-right'
      'w': 'move-to-next-word'
      'b': 'move-to-previous-word'
      '}': 'move-to-next-paragraph'
      'escape': 'reset-command-mode'
      'left': 'move-left'
      'right': 'move-right'

    @handleCommands
      'insert': => @activateInsertMode()
      'delete': => @delete()
      'delete-right': => new commands.DeleteRight(@editor)
      'core:move-left': => new motions.MoveLeft(@editor)
      'core:move-up': => new motions.MoveUp(@editor)
      'core:move-down': => new motions.MoveDown @editor
      'core:move-right': => new motions.MoveRight @editor
      'move-to-next-word': => new motions.MoveToNextWord(@editor)
      'move-to-previous-word': => new motions.MoveToPreviousWord(@editor)
      'move-to-next-paragraph': => new motions.MoveToNextParagraph(@editor)
      'numeric-prefix': (e) => @numericPrefix(e)
      'reset-command-mode': => @resetCommandMode()

  bindCommandModeKeys: (bindings) ->
    prefixedBindings = {}
    for pattern, commandName of bindings
      prefixedBindings[pattern] = "command-mode:#{commandName}"

    window.keymap.bindKeys ".command-mode", prefixedBindings

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

  resetCommandMode: ->
    @opStack = []

  moveCursorBeforeNewline: =>
    if not @editor.getSelection().modifyingSelection and @editor.cursor.isOnEOL() and @editor.getCurrentBufferLine().length > 0
      @editor.setCursorBufferColumn(@editor.getCurrentBufferLine().length - 1)

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
      try
        @topOperator().compose(poppedOperator)
        @processOpStack()
      catch e
        (e instanceof operators.OperatorError) and @resetCommandMode() or throw e
    else
      poppedOperator.execute()

  topOperator: ->
    _.last @opStack
