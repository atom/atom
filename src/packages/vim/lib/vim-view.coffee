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
    if pane = editor.pane()
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
    @enterInsertMode()

    @editor.command "vim:insert-mode", => @enterInsertMode()
    @editor.command "vim:insert-mode-append", => @enterInsertMode("append")
    @editor.command "vim:insert-mode-next-line", => @enterInsertMode("next-line")
    @editor.command "vim:insert-mode-previous-line", => @enterInsertMode("previous-line")
    @editor.command "vim:command-mode", => @enterCommandMode()
    @editor.command 'vim:ex-mode', => @enterExMode()
    @editor.command 'vim:visual-mode', => @enterVisualMode()
    @editor.command 'vim:visual-mode-lines', => @enterVisualMode("lines")
    @editor.command 'vim:cancel-command', => @discardCommand()

    @command 'vim:insert-mode', => @enterInsertMode()
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
      @editor.activeEditSession.commit()
      @insertTransaction = false

  enterInsertMode: (type) ->
    @resetMode()
    switch type
      when 'append' then @state.motion("right")
      when 'next-line' then @state.alias("insert-line-down")
      when 'previous-line' then @state.alias("insert-line-up")
    cursor = @cursor()
    cursor.width = 1
    cursor.updateDisplay()
    @editor.removeClass("command-mode")
    @mode = "insert"
    @updateCommandLine()
    @startTransaction()

  enterCommandMode: ->
    @stopTransaction()
    @resetMode()
    cursor = @cursor()
    cursor.width = @editor.getFontSize()
    cursor.updateDisplay()
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

  addInput: (input) ->
    @runCommand input
    @updateCommandLine()

  executeCommand: () ->
    @runCommand @miniEditor.getText()
    @discardCommand()
    @enterCommandMode()

  runCommand: (input) ->
    for c in input
      if command = VimView.commands[c]
        @editor.trigger command
        true
    false
