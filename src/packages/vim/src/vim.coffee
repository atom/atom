{View, $$} = require 'space-pen'
$ = require 'jquery'
Editor = require 'editor'

module.exports =
class Vim extends View
  @activate: (rootView) ->
    rootView.eachEditor (editor) =>
      @appendToEditorPane(rootView, editor) if editor.attached

  @appendToEditorPane: (rootView, editor) ->
    if pane = editor.pane()
      pane.append(new Vim(rootView, editor))

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
    @enterInsertMode()

    @editor.command "vim:insert-mode", (e) => @enterInsertMode()
    @editor.command "vim:command-mode", (e) => @enterCommandMode()

    @command 'vim:insert-mode', => @enterInsertMode()
    @command 'vim:unfocus', => @rootView.focus()
    @command 'core:close', => @discardCommand()
    @command 'vim:execute', => @executeCommand()
    @command 'vim:ex-mode', => @enterExMode()

    @subscribe $(window), 'focus', => @updateCommandLine()
    @miniEditor.setFontSize "11"

  resetMode: ->
    @mode = "command"
    @editor.addClass("command-mode")

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
    @editor.focus()
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
      @prompt.text(">")

  addInput: (input) ->
    @runCommand input
    @updateCommandLine()

  executeCommand: () ->
    @runCommand @miniEditor.getText()
    @discardCommand()

  runCommand: (input) ->
    for c in input
      if command = Vim.commands[c]
        @editor.trigger command
        true
    false
