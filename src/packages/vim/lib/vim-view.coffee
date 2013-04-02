{View, $$} = require 'space-pen'
$ = require 'jquery'
Editor = require 'editor'
VimState = require './vim-state'

module.exports =
class VimView extends View
  @activate: () ->
    return if config.get("vim.enabled") != true
    rootView.eachEditor (editor) =>
      @appendToEditorPane(rootView, editor) if editor.attached

  @appendToEditorPane: (rootView, editor) ->
    if pane = editor.getPane()
      if pane.find(".vim").length > 0
        return
      statusbar = pane.find(".status-bar")
      view = new VimView(rootView, editor)
      if statusbar.length
        statusbar.before(view)
      else
        pane.append(view)

  @content: ->
    @div class: 'vim', =>
      @div class: 'prompt-and-editor', =>
        @div class: 'prompt', outlet: 'prompt'
        @subview 'miniEditor', new Editor(mini: true)

  @commands:
    'q': "core:close"
    'w': "editor:save"

  initialize: (@rootView, @editor) ->
    requireStylesheet 'vim.css'
    @editor.vim = this
    @vim = $(this)
    @visual = false
    @insertTransaction = false
    @editor.preempt 'textInput', (e) =>
      return true if @inInsertMode()
      text = e.originalEvent.data
      @handleTextInput(text)
      false
    @state = new VimState(@editor, this)
    @enterCommandMode()

    @editor.command 'vim:command-mode', => @state.operation("command")
    @editor.command 'vim:insert-mode', => @state.operation("insert")
    @editor.command 'vim:insert-mode-append', => @state.alias("insert-append")
    @editor.command 'vim:insert-mode-next-line', => @state.alias("insert-line-down")
    @editor.command 'vim:insert-mode-previous-line', => @state.alias("insert-line-up")
    @editor.command 'vim:ex-mode', => @state.operation("ex")
    @editor.command 'vim:visual-mode', => @state.operation("visual")
    @editor.command 'vim:visual-mode-lines', => @state.operation("visual-lines")
    @editor.command 'vim:cancel-command', => @discardCommand()
    @editor.command 'vim:leader', (e) => @leader(e)
    @editor.command 'vim:autocomplete', => @autocomplete()
    @editor.command 'vim:autocomplete-reverse', => @autocomplete(true)
    @editor.command 'vim:search-word', => @searchWord()
    @editor.command 'vim:matching-bracket', => @matchingBracket()

    @command 'vim:unfocus', => @rootView.focus()
    @command 'core:close', => @discardCommand()
    @command 'vim:execute', => @executeCommand()

    for n in [0..9]
      do (n) =>
        @editor.command "vim:count-add-#{n}", => @state.addCountDecimal(n)

    @subscribe $(window), 'focus', => @updateCommandLine()

  resetMode: ->
    @mode = "command"
    @visual = false
    @state.resetState()
    @editor.addClass("command-mode")
    @editor.focus()
    @state.clearSelection()

  cursor: () ->
    @editor.getCursorView()

  leader: (e) ->
    event =
      target: e.target
      keystrokes: 'leader'
      originalEvent:
        keyIdentifier: 'U+FFFF'
    keymap.handleKeyEvent(event)

  stateChanged: (state) ->
    if state == "count"
      @editor.addClass("count")
    else
      @editor.removeClass("count")
    @updateCommandLineText()
  stateUpdated: (state) ->
    if state == "count"
      @updateCommandLineText()

  updateCommandLine: ->
    @updateCommandLineText()

  discardCommand: ->
    @miniEditor.setText("")
    if @inVisualMode()
      @enterCommandMode()
    else
      @resetMode()

  inInsertMode: ->
    @mode is "insert"

  inCommandMode: ->
    @mode is "command"

  inVisualMode: ->
    @mode is "command" && @visual

  inExMode: ->
    @mode is "ex"

  awaitingInput: ->
    @mode is "awaiting-input"

  startedRecording: () ->
    @editor.addClass("recording")
    @updateCommandLine()
  stoppedRecording: () ->
    @editor.removeClass("recording")
    @updateCommandLine()

  startTransaction: ->
    return if @insertTransaction
    @editor.activeEditSession.transact()
    @insertTransaction = true
  stopTransaction: ->
    if @insertTransaction
      if @editor.activeEditSession.buffer.undoManager.currentTransaction?
        @lastTransaction = @editor.activeEditSession.buffer.undoManager.currentTransaction
        @editor.commit()
      @insertTransaction = false
  transaction: ->
    @stopTransaction()
    @startTransaction()

  enterInsertMode: ->
    @resetMode()
    @editor.removeClass("command-mode")
    @mode = "insert"
    @updateCursor()
    @updateCommandLine()
    @startTransaction()

  enterCommandMode: ->
    @stopTransaction()
    @resetMode()
    @updateCursor()
    @updateCommandLine()

  enterExMode: ->
    @resetMode()
    @miniEditor.focus()
    @mode = "ex"
    @updateCommandLine()

  enterVisualMode: (type="normal") ->
    @enterCommandMode()
    @visual = type
    @state.resetState()
    @state.operation("enter-visual-#{type}")
    @updateCommandLine()

  exitVisualMode: () ->
    @visual = false
    @updateCommandLine()

  enterAwaitInputMode: ->
    @editor.removeClass("command-mode")
    @editor.addClass("awaiting-input")
    @mode = "awaiting-input"

  handleTextInput: (text) ->
    @state.input(text)
    if @awaitingInput()
      @enterCommandMode()

  updateCommandLineText: ->
    if @state && @state.recording
      @prompt.text("recording")
    else if @inInsertMode()
      @prompt.text("--INSERT--")
    else if @inVisualMode()
      label = "VISUAL"
      label += " LINES" if @visual == "lines"
      @prompt.text("--#{label}--")
    else if @inExMode()
      @prompt.text(":")
    else
      if @state? and @state.state == "count"
        @prompt.text(@state.count())
      else
        @prompt.text(">")

  updateCursor: ->
    cursor = @cursor()
    cursor.width = if @inInsertMode() then 1 else @editor.getFontSize()
    cursor.updateDisplay()

  addInput: (input) ->
    @runCommand input
    @updateCommandLine()

  executeCommand: () ->
    @state.runCommand @miniEditor.getText()
    @discardCommand()
    @enterCommandMode()

  autocomplete: (reverse=false) ->
    if @autocompleting()
      @editor.trigger(if reverse then "autocomplete:previous" else "autocomplete:next")
    else
      @stopTransaction()
      @editor.trigger("autocomplete:attach")

  autocompleting: () ->
    @editor.find(".autocomplete").length > 0

  searchWord: () ->
    @editor.selectWord()
    word = @editor.getSelectedText()
    @editor.clearSelections()
    @editor.trigger("command-panel:find-in-file")
    rootView.find(".command-panel").view()?.miniEditor.setText("/#{word}")

  matchingBracket: () ->
    @editor.trigger("editor:#{if @inVisualMode() then 'select' else 'go'}-to-matching-bracket")
