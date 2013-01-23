{View, $$} = require 'space-pen'
$ = require 'jquery'

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
      @span class: 'text', outlet: 'commandLine'

  initialize: (@rootView, @editor) ->
    @editor.vim = this
    @mode = "command"
    @updateCommandLine()
    @editor.command "vim:insert-mode", (e) =>
      @mode = "insert"
      @updateCommandLine()
    @editor.command "vim:command-mode", (e) =>
      @mode = "command"
      @updateCommandLine()
    @subscribe $(window), 'focus', => @updateCommandLine()

  updateCommandLine: ->
    @updateCommandLineText()

  inInsertMode: ->
    @mode is "insert"

  inCommandMode: ->
    @mode is "command"

  updateCommandLineText: ->
    if @inInsertMode()
      @commandLine.text("--INSERT--")
    else
      @commandLine.text(":")