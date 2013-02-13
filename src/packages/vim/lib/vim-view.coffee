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
    @state = new VimState(@editor, this)
    @editor.vim = this
    @vim = $(this)
    @enterInsertMode()

    @editor.command "vim:insert-mode", (e) => @enterInsertMode()
    @editor.command "vim:command-mode", (e) => @enterCommandMode()
    @editor.command 'vim:ex-mode', => @enterExMode()
    @editor.command 'vim:cancel-command', => @discardCommand()

    @command 'vim:insert-mode', => @enterInsertMode()
    @command 'vim:unfocus', => @rootView.focus()
    @command 'core:close', => @discardCommand()
    @command 'vim:execute', => @executeCommand()


    @editor.command 'vim:motion-left', => @state.motion("left")
    @editor.command 'vim:motion-right', => @state.motion("right")

    @editor.command "vim:count-add-1", => @state.addCountDecimal(1)
    @editor.command "vim:count-add-2", => @state.addCountDecimal(2)
    @editor.command "vim:count-add-3", => @state.addCountDecimal(3)
    @editor.command "vim:count-add-4", => @state.addCountDecimal(4)
    @editor.command "vim:count-add-5", => @state.addCountDecimal(5)
    @editor.command "vim:count-add-6", => @state.addCountDecimal(6)
    @editor.command "vim:count-add-7", => @state.addCountDecimal(7)
    @editor.command "vim:count-add-8", => @state.addCountDecimal(8)
    @editor.command "vim:count-add-9", => @state.addCountDecimal(9)
    @editor.command "vim:count-add-0", => @state.addCountDecimal(0)

    @subscribe $(window), 'focus', => @updateCommandLine()
    @miniEditor.setFontSize "11"

  resetMode: ->
    @mode = "command"
    @state.resetState()
    @editor.addClass("command-mode")
    @editor.focus()

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
    @editor.removeClass("command-mode")
    @mode = "insert"
    @updateCommandLine()

  enterCommandMode: ->
    @resetMode()
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
