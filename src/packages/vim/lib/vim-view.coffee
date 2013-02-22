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
      pane.append(new VimView(rootView, editor))

  @content: ->
    @div class: 'vim', =>
      @div class: 'prompt-and-editor', =>
        @div class: 'prompt', outlet: 'prompt'
        @subview 'miniEditor', new Editor(mini: true)

  @commands:
    'q': "core:close"
    'w': "editor:save"

  initialize: (@rootView, @editor) ->
    @editor.vim = this
    @vim = $(this)
    @visual = false

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
    @editor.command 'vim:cancel-command', => @discardCommand()

    @command 'vim:insert-mode', => @enterInsertMode()
    @command 'vim:unfocus', => @rootView.focus()
    @command 'core:close', => @discardCommand()
    @command 'vim:execute', => @executeCommand()

    for n in [0..9]
      do (n) =>
        @editor.command "vim:count-add-#{n}", => @state.addCountDecimal(n)

    @subscribe $(window), 'focus', => @updateCommandLine()
    @miniEditor.setFontSize "11"

  resetMode: ->
    @mode = "command"
    @state.resetState()
    @editor.addClass("command-mode")
    @editor.focus()
    @visual = false

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

  enterCommandMode: ->
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

  enterVisualMode: ->
    @enterCommandMode()
    @visual = true
    @state.resetState()
    @updateCommandLine()

  enterAwaitInputMode: ->
    # @enterCommandMode()
    @editor.removeClass("command-mode")
    @editor.addClass("awaiting-input")
    @mode = "awaiting-input"

  handleTextInput: (text) ->
    @state.input(text)
    if @awaitingInput()
      @enterCommandMode()

  updateCommandLineText: ->
    if @inInsertMode()
      @prompt.text("--INSERT--")
    else if @inVisualMode()
      @prompt.text("--VISUAL--")
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
