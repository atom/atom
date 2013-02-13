{View, $$} = require 'space-pen'
$ = require 'jquery'
Editor = require 'editor'
VimState = require './vim-state'

module.exports =
class VimView extends View
  @activate: ->
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

  initialize: (@rootView, @editor) ->
    @editor.vim = this
    @vim = $(this)
    @state = new VimState(@editor, this)
    @enterInsertMode()

    @editor.command "vim:insert-mode", (e) => @enterInsertMode()
    @editor.command "vim:command-mode", (e) => @enterCommandMode()
    @editor.command 'vim:ex-mode', => @enterExMode()
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

  inExMode: ->
    @mode is "ex"

  enterInsertMode: ->
    @resetMode()
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

  updateCommandLineText: ->
    if @inInsertMode()
      @prompt.text("--INSERT--")
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
